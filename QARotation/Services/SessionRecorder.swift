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
    /// Claude 가 먼저 판정해 채워 둔 항목이면 그 근거.
    var claudeNote: String?
    /// Claude 가 결과까지 낸 항목인지. 메모만 남긴(못 본) 항목은 false.
    var claudeJudged = false
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

    /// Claude 가 통과·해당 없음으로 본 항목을 제목으로 찾아 미리 채운다.
    /// 실패는 채우지 않는다. 이미 열린 이슈라서 "다시 확인할 이슈"로 사람이 본다.
    /// 확인하지 못한 항목은 결과 없이 메모(`unchecked`)만 붙인다.
    static func prefill(_ drafts: [DraftResult], from session: QASession?, unchecked: [String: String] = [:]) -> [DraftResult] {
        guard let session else { return drafts }
        let judged = Dictionary(
            (session.results ?? []).filter { $0.outcome != .fail }.map { ($0.itemTitle, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return drafts.map { draft in
            guard let result = judged[draft.title] else {
                var hinted = draft
                hinted.claudeNote = unchecked[draft.title]
                return hinted
            }
            var filled = draft
            filled.outcome = result.outcome
            filled.claudeNote = result.note
            filled.claudeJudged = true
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
            let result = ItemResult(
                itemTitle: draft.title,
                category: draft.category,
                order: draft.order,
                outcome: outcome,
                // Claude 기록은 통과에도 근거를 남긴다. 사람이 이어서 볼 때 무엇을 봤는지 알 수 있게.
                note: outcome == .fail || byClaude ? note : "",
                screenshot: outcome == .fail || byClaude ? draft.screenshot : nil
            )
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
