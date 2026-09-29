import Foundation
import SwiftData

/// 세션 중 아직 저장하지 않은 항목. 완료를 누르기 전까지는 저장소에 아무것도 남기지 않는다.
struct DraftResult: Identifiable, Equatable {
    let id: UUID
    let title: String
    let steps: String
    let category: ChecklistCategory
    let verification: Verification
    let order: Int
    let isAppSpecific: Bool
    var outcome: Outcome?
    var note: String = ""
    var screenshot: Data?
    /// 지난 기록에서 이어받아 미리 채운 결과. 사람이 바꾸지 않으면 그대로 기록된다.
    var carriedOutcome: Outcome?
    /// 이어받은 결과가 맥에서 자동으로 확인한 것인지(아니면 지난번에 손으로 본 것).
    var carriedFromClaude = false
    /// Claude 가 먼저 판정해 채워 둔 항목이면 그 근거, 확인하지 못한 항목이면 못 본 이유.
    var claudeNote: String?

    /// Claude 가 결과까지 낸 항목인지. 메모만 남긴(못 본) 항목은 false.
    var claudeJudged: Bool { carriedFromClaude && carriedOutcome != nil }
    /// 이어받은 결과를 사람이 바꾸지 않고 둔 항목.
    var isCarried: Bool { carriedOutcome != nil && outcome == carriedOutcome }
}

/// 새 세션에 미리 채울 지난 결과.
struct CarriedResult: Equatable {
    let outcome: Outcome
    let note: String
    let byClaude: Bool
}

enum ReverifyDecision: String, Sendable {
    case fixed
    case stillFailing
}

struct SessionMeta: Equatable {
    var startedAt: Date
    var deviceModel: String
    var osVersion: String
    var appVersion: String
}

@MainActor
enum SessionRecorder {
    /// 체크리스트 = 기본 항목(분류 → 순서) + 앱 전용 항목(순서).
    static func drafts(defaultItems: [ChecklistItem], app: TrackedApp) -> [DraftResult] {
        // 기본 항목의 단계는 앱마다 다르게 적어 둔 것이 있으면 그것을 쓴다.
        let appSteps = AppChecklistCatalog.defaultSteps(for: app.bundleID)
        let defaults = defaultItems
            .sorted { ($0.category.sortIndex, $0.order) < ($1.category.sortIndex, $1.order) }
            .map { DraftResult(id: $0.id, title: $0.title, steps: appSteps[$0.title] ?? $0.steps, category: $0.category, verification: $0.verification, order: 0, isAppSpecific: false) }
        let extras = app.sortedExtraItems
            .map { DraftResult(id: $0.id, title: $0.title, steps: $0.steps, category: $0.category, verification: $0.verification, order: 0, isAppSpecific: true) }
        return (defaults + extras).enumerated().map { index, draft in
            DraftResult(
                id: draft.id,
                title: draft.title,
                steps: draft.steps,
                category: draft.category,
                verification: draft.verification,
                order: index,
                isAppSpecific: draft.isAppSpecific
            )
        }
    }

    /// Claude 기록에서 이어받을 결과. 그 기록의 결과는 모두 자동으로 본 것이다.
    static func carried(from session: QASession?) -> [String: CarriedResult] {
        guard let session else { return [:] }
        return Dictionary(
            (session.results ?? []).map { ($0.itemTitle, CarriedResult(outcome: $0.outcome, note: $0.note, byClaude: true)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 지난 결과를 제목으로 찾아 미리 채운다.
    /// 실패는 채우지 않는다. 이미 열린 이슈라서 "다시 확인할 이슈"로 사람이 본다.
    /// 아직 아무도 확인하지 못한 항목은 결과 없이 Claude 의 메모(`unchecked`)만 붙인다.
    static func prefill(_ drafts: [DraftResult], carried: [String: CarriedResult], unchecked: [String: String] = [:]) -> [DraftResult] {
        drafts.map { draft in
            guard let result = carried[draft.title], result.outcome != .fail else {
                var hinted = draft
                hinted.claudeNote = unchecked[draft.title]
                return hinted
            }
            var filled = draft
            filled.outcome = result.outcome
            filled.carriedOutcome = result.outcome
            filled.carriedFromClaude = result.byClaude
            if result.byClaude { filled.claudeNote = result.note }
            return filled
        }
    }

    /// 답하지 않은 항목은 기록하지 않는다. 실패 항목은 이슈가 된다.
    /// 같은 제목의 이슈가 이미 열려 있으면 새로 만들지 않고 그 이슈에 이번 결과를 잇는다.
    @discardableResult
    static func record(
        app: TrackedApp,
        drafts: [DraftResult],
        reverify: [UUID: ReverifyDecision],
        meta: SessionMeta,
        byClaude: Bool = false,
        in context: ModelContext,
        now: Date = .now
    ) throws -> QASession {
        let session = QASession(
            date: meta.startedAt,
            deviceModel: meta.deviceModel,
            osVersion: meta.osVersion,
            appVersion: meta.appVersion,
            durationSeconds: max(0, Int(now.timeIntervalSince(meta.startedAt)))
        )
        session.byClaude = byClaude
        context.insert(session)
        session.app = app

        var failedTitles = Set<String>()
        for draft in drafts {
            guard let outcome = draft.outcome else { continue }
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            // 사람이 이어받아 그대로 둔 Claude 결과도 자동으로 본 것으로 남긴다.
            let automatic = byClaude || (draft.isCarried && draft.carriedFromClaude)
            let result = ItemResult(
                itemTitle: draft.title,
                category: draft.category,
                order: draft.order,
                outcome: outcome,
                // Claude 결과는 통과에도 근거를 남긴다. 사람이 이어서 볼 때 무엇을 봤는지 알 수 있게.
                note: outcome == .fail || byClaude ? note : (automatic ? draft.claudeNote ?? "" : ""),
                screenshot: outcome == .fail || byClaude ? draft.screenshot : nil
            )
            result.byClaude = automatic
            context.insert(result)
            result.session = session

            guard outcome == .fail else { continue }
            failedTitles.insert(draft.title)

            if let existing = app.openIssues.first(where: { $0.title == draft.title }) {
                existing.sourceResult = result
                if !note.isEmpty {
                    existing.note = existing.note.isEmpty ? note : existing.note + "\n" + note
                }
                if let shot = draft.screenshot { existing.screenshot = shot }
            } else {
                let issue = Issue(title: draft.title, category: draft.category, note: note, screenshot: draft.screenshot, createdAt: now)
                context.insert(issue)
                issue.app = app
                issue.sourceResult = result
            }
        }

        // 다시 확인한 이슈: "고쳐졌어요"여도 이번에 같은 항목이 실패했으면 열린 채로 둔다.
        for issue in app.issues ?? [] {
            guard reverify[issue.id] == .fixed, issue.status == .open, !failedTitles.contains(issue.title) else { continue }
            issue.setStatus(.fixed, now: now)
        }

        if !byClaude { app.lastQADate = meta.startedAt }
        // 다음 QA도 같은 버전으로 이어 가도록, 이번에 기록한 버전을 앱에 남긴다.
        app.testingVersion = meta.appVersion.trimmingCharacters(in: .whitespaces)
        try context.save()
        return session
    }
}
