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
    let timerSeconds: Int

    /// 보관해 둔 진행 상태가 있으면 이어서 시작한다. 없으면 처음부터.
    init(
        app: TrackedApp,
        defaultItems: [ChecklistItem],
        timerMinutes: Int,
        resuming stored: SessionDraft? = nil,
        now: Date = .now
    ) {
        self.app = app
        self.drafts = SessionRecorder.drafts(defaultItems: defaultItems, app: app)
        self.reverifyIssues = app.openIssues
        self.timerSeconds = timerMinutes * 60

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

    var sections: [CategorySection] {
        let grouped = Dictionary(grouping: drafts, by: \.category)
        return ChecklistCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return CategorySection(category: category, itemIDs: items.sorted { $0.order < $1.order }.map(\.id))
        }
    }

    var answeredCount: Int { drafts.filter { $0.outcome != nil }.count }
    var unansweredCount: Int { drafts.count - answeredCount }
    var failCount: Int { drafts.filter { $0.outcome == .fail }.count }
    var hasProgress: Bool { answeredCount > 0 || !reverify.isEmpty }

    func index(of id: UUID) -> Int? { drafts.firstIndex { $0.id == id } }

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
