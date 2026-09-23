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

@Suite("보던 자리 기억하기")
@MainActor
struct RouterMemoryTests {
    func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "RouterMemoryTests-\(UUID().uuidString)")!
    }

    @Test func 처음에는_오늘_탭이고_열린_세션이_없다() {
        let router = Router(defaults: makeDefaults())
        #expect(router.selectedTab == .today)
        #expect(router.activeSession == nil)
    }

    @Test func 보던_탭이_다음_실행에도_남는다() {
        let defaults = makeDefaults()
        let first = Router(defaults: defaults)
        first.selectedTab = .issues

        #expect(Router(defaults: defaults).selectedTab == .issues)
    }

    @Test func QA하던_앱이_다음_실행에_다시_열린다() {
        let defaults = makeDefaults()
        let appID = UUID()
        let first = Router(defaults: defaults)
        first.startSession(appID)

        let second = Router(defaults: defaults)
        #expect(second.activeSession?.appID == appID)
    }

    @Test func 앱_탭에서_시작하면_탭이_바뀌지_않는다() {
        let router = Router(defaults: makeDefaults())
        router.selectedTab = .apps
        router.startSession(UUID())

        #expect(router.selectedTab == .apps)
    }

    @Test func 위젯이나_알림으로_들어오면_오늘_탭에서_연다() {
        let router = Router(defaults: makeDefaults())
        router.selectedTab = .settings
        let appID = UUID()
        router.handle(DeepLink.session(appID).url)

        #expect(router.selectedTab == .today)
        #expect(router.activeSession?.appID == appID)
    }

    @Test func 세션을_닫으면_다시_열리지_않는다() {
        let defaults = makeDefaults()
        let first = Router(defaults: defaults)
        first.startSession(UUID())
        first.activeSession = nil

        #expect(Router(defaults: defaults).activeSession == nil)
    }
}

@Suite("한 장씩 보기")
@MainActor
struct FocusedChecklistTests {
    @Test func 단계를_할_일과_확인할_것으로_가른다() {
        let broken = StepText.broken("앱 전환기에서 앱을 밀어 끈다 → 홈에서 아이콘을 누른다 → 3초 안에 첫 화면이 뜬다")
        #expect(broken.actions == ["앱 전환기에서 앱을 밀어 끈다", "홈에서 아이콘을 누른다"])
        #expect(broken.expectation == "3초 안에 첫 화면이 뜬다")
    }

    @Test func 토막이_하나면_그것이_확인할_내용이다() {
        let broken = StepText.broken("빌드 경고 목록에 deprecated가 없다")
        #expect(broken.actions.isEmpty)
        #expect(broken.expectation == "빌드 경고 목록에 deprecated가 없다")
    }

    @Test func 단계가_비면_보여_줄_것이_없다() {
        #expect(StepText.broken("").isEmpty)
        #expect(StepText.broken("  →  ").isEmpty)
    }

    @Test func 클립키보드만_한_장씩으로_열린다() {
        #expect(FocusMode.opensFocused(bundleID: "com.Ysoup.TokenMemo"))
        #expect(FocusMode.opensFocused(bundleID: "com.ysoup.tokenmemo"))
        #expect(!FocusMode.opensFocused(bundleID: "com.ysoup.TokenMemo-tap"))
        #expect(!FocusMode.opensFocused(bundleID: "com.leeo.SkyDex"))
    }

    @Test func 답하면_다음_빈_항목으로_넘어간다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let app = TrackedApp(name: "앱")
        context.insert(app)
        let items = (0..<4).map { ChecklistItem(title: "항목 \($0)", category: .stability, order: $0, isDefault: true) }
        for item in items { context.insert(item) }
        try context.save()

        let model = SessionViewModel(app: app, defaultItems: items, timerMinutes: 7)
        #expect(model.nextUnanswered(after: 0) == 1)

        model.drafts[1].outcome = .pass
        #expect(model.nextUnanswered(after: 0) == 2)

        // 뒤가 다 찼으면 앞으로 돌아가 빈 곳을 찾는다.
        model.drafts[2].outcome = .pass
        model.drafts[3].outcome = .pass
        #expect(model.nextUnanswered(after: 2) == 0)

        model.drafts[0].outcome = .na
        #expect(model.nextUnanswered(after: 2) == nil)
    }
}
