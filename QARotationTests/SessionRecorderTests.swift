import Foundation
import SwiftData
import Testing
@testable import QARotation

@Suite("QA 세션 기록")
@MainActor
struct SessionRecorderTests {
    let container: ModelContainer
    let context: ModelContext
    let app: TrackedApp
    let defaults: [ChecklistItem]

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
        app = TrackedApp(name: "테스트앱", currentVersion: "3.0")
        context.insert(app)
        defaults = [
            ChecklistItem(title: "구매 복원", category: .monetization, order: 1, isDefault: true),
            ChecklistItem(title: "실행", category: .stability, order: 0, isDefault: true),
        ]
        for item in defaults { context.insert(item) }
        let extra = ChecklistItem(title: "위젯 갱신", category: .custom, order: 0, isDefault: false)
        context.insert(extra)
        extra.app = app
        try context.save()
    }

    func meta(_ start: Date = .now) -> SessionMeta {
        SessionMeta(startedAt: start, deviceModel: "iPhone", osVersion: "iOS 26.0", appVersion: "3.0")
    }

    func drafts(_ outcomes: [String: Outcome], notes: [String: String] = [:]) -> [DraftResult] {
        SessionRecorder.drafts(defaultItems: defaults, app: app).map { draft in
            var d = draft
            d.outcome = outcomes[d.title]
            d.note = notes[d.title] ?? ""
            return d
        }
    }

    @Test func 체크리스트는_기본_분류순_다음_앱_전용이다() {
        let list = SessionRecorder.drafts(defaultItems: defaults, app: app)
        #expect(list.map(\.title) == ["실행", "구매 복원", "위젯 갱신"])
        #expect(list.map(\.isAppSpecific) == [false, false, true])
    }

    @Test func 모두_통과면_이슈가_없고_마지막_QA가_갱신된다() throws {
        let start = Date.now.addingTimeInterval(-300)
        let session = try SessionRecorder.record(
            app: app,
            drafts: drafts(["실행": .pass, "구매 복원": .pass, "위젯 갱신": .pass]),
            reverify: [:],
            meta: meta(start),
            in: context
        )
        #expect(session.results?.count == 3)
        #expect((app.issues ?? []).isEmpty)
        #expect(app.lastQADate == start)
        #expect(session.durationSeconds >= 299)
    }

    @Test func 실패하면_이슈가_생긴다() throws {
        try SessionRecorder.record(
            app: app,
            drafts: drafts(["실행": .pass, "구매 복원": .fail], notes: ["구매 복원": "  무한 로딩  "]),
            reverify: [:],
            meta: meta(),
            in: context
        )
        let issue = try #require(app.openIssues.first)
        #expect(app.openIssues.count == 1)
        #expect(issue.title == "구매 복원")
        #expect(issue.note == "무한 로딩")
        #expect(issue.category == .monetization)
        #expect(issue.sourceResult?.outcome == .fail)
    }

    @Test func 답하지_않은_항목은_기록하지_않는다() throws {
        let session = try SessionRecorder.record(app: app, drafts: drafts(["실행": .pass]), reverify: [:], meta: meta(), in: context)
        #expect(session.results?.count == 1)
    }

    @Test func 같은_항목이_또_실패하면_이슈를_새로_만들지_않는다() throws {
        try SessionRecorder.record(app: app, drafts: drafts(["실행": .fail], notes: ["실행": "첫 번째"]), reverify: [:], meta: meta(), in: context)
        try SessionRecorder.record(app: app, drafts: drafts(["실행": .fail], notes: ["실행": "두 번째"]), reverify: [:], meta: meta(), in: context)
        #expect(app.openIssues.count == 1)
        #expect(app.openIssues.first?.note == "첫 번째\n두 번째")
    }

    @Test func 다시_확인에서_고쳐졌으면_이슈를_닫는다() throws {
        try SessionRecorder.record(app: app, drafts: drafts(["실행": .fail]), reverify: [:], meta: meta(), in: context)
        let issue = try #require(app.openIssues.first)

        try SessionRecorder.record(app: app, drafts: drafts(["실행": .pass]), reverify: [issue.id: .fixed], meta: meta(), in: context)
        #expect(issue.status == .fixed)
        #expect(issue.resolvedAt != nil)
        #expect(app.openIssues.isEmpty)
    }

    @Test func 고쳐졌다고_해도_이번에_또_실패했으면_열어_둔다() throws {
        try SessionRecorder.record(app: app, drafts: drafts(["실행": .fail]), reverify: [:], meta: meta(), in: context)
        let issue = try #require(app.openIssues.first)

        try SessionRecorder.record(app: app, drafts: drafts(["실행": .fail]), reverify: [issue.id: .fixed], meta: meta(), in: context)
        #expect(issue.status == .open)
    }

    @Test func 체크리스트를_고쳐도_지난_기록_문구는_그대로다() throws {
        let session = try SessionRecorder.record(app: app, drafts: drafts(["실행": .pass]), reverify: [:], meta: meta(), in: context)
        defaults.first { $0.title == "실행" }?.title = "앱이 실행된다"
        try context.save()
        #expect(session.results?.first?.itemTitle == "실행")
    }

    @Test func 이슈_상태를_되돌리면_정리_시각이_지워진다() {
        let issue = Issue(title: "x", category: .custom, note: "", screenshot: nil, createdAt: .now)
        issue.setStatus(.wontFix)
        #expect(issue.resolvedAt != nil)
        issue.setStatus(.open)
        #expect(issue.resolvedAt == nil)
    }
}

@Suite("딥링크")
struct DeepLinkTests {
    @Test func 세션_링크를_왕복한다() {
        let id = UUID()
        #expect(DeepLink(url: DeepLink.session(id).url) == .session(id))
        #expect(DeepLink(url: DeepLink.today.url) == .today)
    }

    @Test func 모르는_링크는_무시한다() {
        #expect(DeepLink(url: URL(string: "https://example.com/session/abc")!) == nil)
        #expect(DeepLink(url: URL(string: "qarotation://session/not-a-uuid")!) == nil)
        #expect(DeepLink(url: URL(string: "qarotation://unknown")!) == nil)
    }
}
