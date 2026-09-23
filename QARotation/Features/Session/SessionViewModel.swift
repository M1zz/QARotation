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

    init(app: TrackedApp, defaultItems: [ChecklistItem], timerMinutes: Int, now: Date = .now) {
        self.app = app
        self.drafts = SessionRecorder.drafts(defaultItems: defaultItems, app: app)
        self.reverifyIssues = app.openIssues
        self.meta = SessionMeta(
            startedAt: now,
            deviceModel: DeviceInfo.deviceModel,
            osVersion: DeviceInfo.osVersion,
            appVersion: app.versionUnderTest
        )
        self.timerSeconds = timerMinutes * 60
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
    }

    func markRemainingPass() {
        for i in drafts.indices where drafts[i].outcome == nil {
            drafts[i].outcome = .pass
        }
    }

    func setReverify(_ decision: ReverifyDecision, for issue: Issue) {
        reverify[issue.id] = reverify[issue.id] == decision ? nil : decision
    }

    func finish(in context: ModelContext) throws {
        try SessionRecorder.record(app: app, drafts: drafts, reverify: reverify, meta: meta, in: context)
        PickChangeCoordinator.pickDidChange(context: context)
    }
}
