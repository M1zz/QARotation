import Foundation
import SwiftData
import Testing
@testable import QARotation

@Suite("하던 QA 이어서 하기")
@MainActor
struct SessionDraftTests {
    let container: ModelContainer
    let context: ModelContext
    let defaults: UserDefaults
    let app: TrackedApp
    let items: [ChecklistItem]

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
        defaults = UserDefaults(suiteName: "SessionDraftTests-\(UUID().uuidString)")!
        app = TrackedApp(name: "테스트앱", currentVersion: "1.0")
        context.insert(app)
        items = [
            ChecklistItem(title: "실행", category: .stability, order: 0, isDefault: true),
            ChecklistItem(title: "구매", category: .monetization, order: 1, isDefault: true),
            ChecklistItem(title: "다크 모드", category: .appearance, order: 2, isDefault: true),
        ]
        for item in items { context.insert(item) }
        try context.save()
    }

    func model(resuming stored: SessionDraft? = nil, now: Date = .now) -> SessionViewModel {
        SessionViewModel(app: app, defaultItems: items, timerMinutes: 7, resuming: stored, now: now)
    }

    @Test func 답을_누르면_보관함에_남는다() throws {
        let first = model()
        let id = try #require(first.drafts.first?.id)
        first.setOutcome(.fail, for: id)
        first.drafts[0].note = "여기서 튕김"
        first.keepDraft(defaults: defaults)

        let stored = try #require(SessionDraftStore.load(defaults))
        #expect(stored.appID == app.id)
        #expect(stored.answeredCount == 1)
        #expect(stored.totalCount == 3)
        #expect(stored.outcomes[id.uuidString] == Outcome.fail.rawValue)
        #expect(stored.notes[id.uuidString] == "여기서 튕김")
    }

    @Test func 이어서_열면_답과_메모와_쓴_시간이_돌아온다() throws {
        let start = Date.now.addingTimeInterval(-300)
        let first = model(now: start)
        let id = try #require(first.drafts.first?.id)
        first.setOutcome(.pass, for: id)
        first.drafts[0].note = "메모"
        first.meta.appVersion = "1.1"
        let savedAt = start.addingTimeInterval(120)
        first.keepDraft(now: savedAt, defaults: defaults)

        let stored = try #require(SessionDraftStore.load(defaults))
        let resumed = model(resuming: stored, now: savedAt.addingTimeInterval(600))
        #expect(resumed.answeredCount == 1)
        #expect(resumed.drafts[0].outcome == .pass)
        #expect(resumed.drafts[0].note == "메모")
        #expect(resumed.meta.appVersion == "1.1")
        // 쉬는 동안 흐른 10분은 빼고, 실제로 QA한 2분에서 이어 센다.
        #expect(abs(resumed.meta.startedAt.timeIntervalSince(savedAt.addingTimeInterval(480))) < 1)
    }

    @Test func 다른_앱_보관함은_이어받지_않는다() throws {
        let other = TrackedApp(name: "다른앱")
        context.insert(other)
        let stored = SessionDraft(
            appID: other.id,
            savedAt: .now,
            elapsedSeconds: 60,
            deviceModel: "iPhone",
            osVersion: "iOS 26.0",
            appVersion: "9.9",
            outcomes: [UUID().uuidString: Outcome.fail.rawValue],
            notes: [:],
            reverify: [:],
            answeredCount: 1,
            totalCount: 3
        )
        let fresh = model(resuming: stored)
        #expect(fresh.answeredCount == 0)
        #expect(fresh.meta.appVersion == "1.0")
    }

    @Test func 아무것도_안_눌렀으면_보관하지_않는다() {
        model().keepDraft(defaults: defaults)
        #expect(SessionDraftStore.load(defaults) == nil)
    }

    @Test func 완료하면_보관함이_비워진다() throws {
        SessionDraftStore.save(
            SessionDraft(
                appID: app.id,
                savedAt: .now,
                elapsedSeconds: 30,
                deviceModel: "iPhone",
                osVersion: "iOS 26.0",
                appVersion: "1.0",
                outcomes: [:],
                notes: [:],
                reverify: [UUID().uuidString: ReverifyDecision.fixed.rawValue],
                answeredCount: 0,
                totalCount: 3
            ),
            to: defaults
        )
        #expect(SessionDraftStore.load(defaults) != nil)
        SessionDraftStore.clear(defaults)
        #expect(SessionDraftStore.load(defaults) == nil)
    }
}
