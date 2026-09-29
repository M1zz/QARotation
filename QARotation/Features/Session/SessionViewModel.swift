import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SessionViewModel {
    struct CategorySection: Identifiable {
        let category: ChecklistCategory
        let itemIDs: [UUID]
        var id: ChecklistCategory { category }
    }

    let app: TrackedApp
    var drafts: [DraftResult]
    let reverifyIssues: [Issue]
    var reverify: [UUID: ReverifyDecision] = [:]
    var meta: SessionMeta
    /// 이어서 보는 Claude 기록. 통과·해당 없음은 미리 채우고, 실패는 이슈로 다시 확인한다.
    let claudeSession: QASession?
    /// 버전 QA지를 이어서 채우는 세션인지. 그 버전에서 이미 본 결과(자동·수동)를 모두 미리 채운다.
    let continuesSheet: Bool
    private let initialDrafts: [DraftResult]

    /// 보관해 둔 진행 상태가 있으면 이어서 시작한다. 없으면 처음부터.
    init(
        app: TrackedApp,
        defaultItems: [ChecklistItem],
        resuming stored: SessionDraft? = nil,
        continuingSheet: Bool = false,
        now: Date = .now
    ) {
        self.app = app
        let base = SessionRecorder.drafts(defaultItems: defaultItems, app: app)
        let prefilled: [DraftResult]
        if continuingSheet {
            let sheet = VersionSheet.build(version: app.versionUnderTest, sessions: app.sortedSessions, checklist: base)
            prefilled = SessionRecorder.prefill(base, carried: sheet.carried, unchecked: sheet.uncheckedNotes)
            self.claudeSession = nil
        } else {
            let claude = app.pendingClaudeSession
            prefilled = SessionRecorder.prefill(
                base,
                carried: SessionRecorder.carried(from: claude),
                unchecked: claude?.claudeUncheckedNotes ?? [:]
            )
            self.claudeSession = claude
        }
        self.continuesSheet = continuingSheet
        self.drafts = prefilled
        self.initialDrafts = prefilled
        self.reverifyIssues = app.openIssues

        if let stored, stored.appID == app.id {
            // 쓴 시간을 이어 세려고 시작 시각을 거꾸로 잡는다.
            self.meta = SessionMeta(
                startedAt: now.addingTimeInterval(-Double(stored.elapsedSeconds)),
                deviceModel: stored.deviceModel,
                osVersion: stored.osVersion,
                appVersion: stored.appVersion
            )
            for index in drafts.indices {
                let id = drafts[index].id.uuidString
                if let raw = stored.outcomes[id] { drafts[index].outcome = Outcome(rawValue: raw) }
                if let note = stored.notes[id] { drafts[index].note = note }
            }
            for issue in reverifyIssues {
                if let raw = stored.reverify[issue.id.uuidString] {
                    reverify[issue.id] = ReverifyDecision(rawValue: raw)
                }
            }
        } else {
            self.meta = SessionMeta(
                startedAt: now,
                deviceModel: DeviceInfo.deviceModel,
                osVersion: DeviceInfo.osVersion,
                appVersion: app.versionUnderTest
            )
        }
    }

    /// 지금 상태를 보관함에 맡긴다. 답을 누를 때와 화면을 떠날 때 부른다.
    func keepDraft(now: Date = .now, defaults: UserDefaults = .shared) {
        var outcomes: [String: String] = [:]
        var notes: [String: String] = [:]
        for draft in drafts {
            if let outcome = draft.outcome { outcomes[draft.id.uuidString] = outcome.rawValue }
            let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty { notes[draft.id.uuidString] = note }
        }
        let decisions = reverify.reduce(into: [String: String]()) { $0[$1.key.uuidString] = $1.value.rawValue }
        SessionDraftStore.save(
            SessionDraft(
                appID: app.id,
                savedAt: now,
                elapsedSeconds: max(0, Int(now.timeIntervalSince(meta.startedAt))),
                deviceModel: meta.deviceModel,
                osVersion: meta.osVersion,
                appVersion: meta.appVersion,
                outcomes: outcomes,
                notes: notes,
                reverify: decisions,
                answeredCount: answeredCount,
                totalCount: drafts.count
            ),
            to: defaults
        )
    }

    var sections: [CategorySection] { sections { _ in true } }

    /// 미리 채워 둔 항목이 있는지. 있으면 목록을 "손으로 할 것"과 "이미 확인한 것"으로 나눈다.
    var hasCarried: Bool { drafts.contains { $0.carriedOutcome != nil } }
    var carriedCount: Int { drafts.filter { $0.carriedOutcome != nil }.count }

    func sections(where include: (DraftResult) -> Bool) -> [CategorySection] {
        let grouped = Dictionary(grouping: drafts.filter(include), by: \.category)
        return ChecklistCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return CategorySection(category: category, itemIDs: items.sorted { $0.order < $1.order }.map(\.id))
        }
    }

    var answeredCount: Int { drafts.filter { $0.outcome != nil }.count }
    var unansweredCount: Int { drafts.count - answeredCount }
    var failCount: Int { drafts.filter { $0.outcome == .fail }.count }
    var hasProgress: Bool { answeredCount > 0 || !reverify.isEmpty }
    /// 미리 채운 것 말고 사람이 바꾼 것이 있는지. 닫을 때 확인을 받을지 정한다.
    var hasChanges: Bool { drafts != initialDrafts || !reverify.isEmpty }
    var claudeFilledCount: Int { drafts.filter(\.claudeJudged).count }

    func index(of id: UUID) -> Int? { drafts.firstIndex { $0.id == id } }

    /// 한 장씩 보는 화면에서 다음으로 물어볼 항목. 뒤를 먼저 훑고, 없으면 앞으로 돌아간다.
    func nextUnanswered(after index: Int) -> Int? {
        if let ahead = drafts.indices.first(where: { $0 > index && drafts[$0].outcome == nil }) { return ahead }
        return drafts.indices.first { $0 < index && drafts[$0].outcome == nil }
    }

    /// 같은 결과를 다시 누르면 선택을 푼다(잘못 누른 걸 되돌리기).
    func setOutcome(_ outcome: Outcome, for id: UUID) {
        guard let i = index(of: id) else { return }
        drafts[i].outcome = drafts[i].outcome == outcome ? nil : outcome
        keepDraft()
    }

    func markRemainingPass() {
        for i in drafts.indices where drafts[i].outcome == nil {
            drafts[i].outcome = .pass
        }
        keepDraft()
    }

    func setReverify(_ decision: ReverifyDecision, for issue: Issue) {
        reverify[issue.id] = reverify[issue.id] == decision ? nil : decision
        keepDraft()
    }

    func finish(in context: ModelContext) throws {
        try SessionRecorder.record(app: app, drafts: drafts, reverify: reverify, meta: meta, in: context)
        SessionDraftStore.clear()
        PickChangeCoordinator.pickDidChange(context: context)
    }
}
