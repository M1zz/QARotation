import Foundation
import SwiftData
import Testing
@testable import QARotation

@Suite("Claude 기록 이어받기")
@MainActor
struct ClaudeQASeederTests {
    let container: ModelContainer
    let context: ModelContext
    let app: TrackedApp

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
        app = TrackedApp(name: "클립키보드", currentVersion: "5.1.6")
        app.bundleID = "com.Ysoup.TokenMemo"
        context.insert(app)
        for (order, title) in ["검색", "분류", "키보드 입력"].enumerated() {
            let item = ChecklistItem(title: title, category: .custom, order: order, isDefault: false)
            context.insert(item)
            item.app = app
        }
        try context.save()
    }

    func run(start: Date) -> ClaudeQARuns.Run {
        let json = """
        {"id":"t1","bundleID":"com.ysoup.tokenmemo","startedAt":"\(ISO8601DateFormatter().string(from: start))",
         "durationSeconds":600,"deviceModel":"Claude · 시뮬레이터","osVersion":"iOS 27.0","appVersion":"5.1.6",
         "results":[{"title":"검색","outcome":"pass","note":"테스트 통과"},
                    {"title":"분류","outcome":"fail","note":"전화번호가 계좌로 분류됨"},
                    {"title":"키보드 입력","note":"실기기 필요"}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(ClaudeQARuns.Run.self, from: Data(json.utf8))
    }

    @Test func Claude_기록은_마지막_QA를_올리지_않고_실패는_이슈가_된다() throws {
        let start = Date.now.addingTimeInterval(-3600)
        try ClaudeQASeeder.record(run(start: start), app: app, in: context)

        let session = try #require(app.sortedSessions.first)
        #expect(session.byClaude)
        #expect(session.results?.count == 2)
        #expect(session.sortedResults.first?.note == "테스트 통과")
        #expect(app.lastQADate == nil)
        #expect(app.openIssues.map(\.title) == ["분류"])
        #expect(app.pendingClaudeSession?.id == session.id)
    }

    @Test func 이어서_보면_통과만_채워지고_사람이_완료하면_끝난다() throws {
        try ClaudeQASeeder.record(run(start: .now.addingTimeInterval(-3600)), app: app, in: context)

        let model = SessionViewModel(app: app, defaultItems: [])
        #expect(model.claudeFilledCount == 1)
        #expect(model.drafts.first { $0.title == "검색" }?.outcome == .pass)
        #expect(model.drafts.first { $0.title == "분류" }?.outcome == nil)
        #expect(model.reverifyIssues.map(\.title) == ["분류"])
        #expect(!model.hasChanges)

        model.setOutcome(.pass, for: try #require(model.drafts.first { $0.title == "키보드 입력" }).id)
        #expect(model.hasChanges)
        try model.finish(in: context)

        #expect(app.lastQADate != nil)
        #expect(app.pendingClaudeSession == nil)
    }

    @Test func 앱에_넣은_결과지는_읽히고_제목이_체크리스트와_맞는다() throws {
        let runs = ClaudeQARuns.load()
        let run = try #require(runs.first { $0.bundleID == "com.Ysoup.TokenMemo" })
        let catalog = Set(AppChecklistCatalog.items(for: run.bundleID).map(\.1))
        let defaults = Set(DefaultChecklist.items.map(\.1))
        let titles = Set(run.results.map(\.title))
        #expect(catalog.isSubset(of: titles))
        #expect(defaults.isSubset(of: titles))
        for entry in run.results where entry.screenshot != nil {
            #expect(ClaudeQARuns.screenshot(named: entry.screenshot) != nil, "\(entry.title)")
        }
    }
}
