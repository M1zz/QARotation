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
        let renamed = AppChecklistCatalog.renamedTitles[AppChecklistCatalog.key(run.bundleID)] ?? [:]
        let titles = Set(run.results.map { renamed[$0.title] ?? $0.title })
        #expect(defaults.isSubset(of: titles))
        // 결과지는 그날의 목록을 본 것이다. 그 뒤 카탈로그에 더한 항목은 없어도 되지만,
        // 결과지의 제목은 (이름을 바꾼 것까지 따라가면) 지금 목록에 있어야 이어받을 수 있다.
        // 목록 밖에서 Claude가 따로 찾은 문제는 실패로만 남는다.
        for entry in run.results where !catalog.contains(renamed[entry.title] ?? entry.title) && !defaults.contains(entry.title) {
            #expect(entry.outcome == Outcome.fail.rawValue, "\(entry.title)")
        }
        for entry in run.results where entry.screenshot != nil {
            #expect(ClaudeQARuns.screenshot(named: entry.screenshot) != nil, "\(entry.title)")
        }
    }

    @Test func 사람이_그대로_둔_Claude_결과는_자동으로_남고_QA지가_자동_수동_남은_것으로_나뉜다() throws {
        try ClaudeQASeeder.record(run(start: .now.addingTimeInterval(-3600)), app: app, in: context)

        let model = SessionViewModel(app: app, defaultItems: [])
        #expect(model.drafts.first { $0.title == "키보드 입력" }?.claudeNote == "실기기 필요")
        model.setOutcome(.pass, for: try #require(model.drafts.first { $0.title == "키보드 입력" }).id)
        try model.finish(in: context)

        let human = try #require(app.sortedSessions.first { !$0.byClaude })
        #expect(human.sortedResults.first { $0.itemTitle == "검색" }?.byClaude == true)
        #expect(human.sortedResults.first { $0.itemTitle == "검색" }?.note == "테스트 통과")
        #expect(human.sortedResults.first { $0.itemTitle == "키보드 입력" }?.byClaude == false)

        let checklist = SessionRecorder.drafts(defaultItems: [], app: app)
        let sheet = VersionSheet.build(version: "5.1.6", sessions: app.sortedSessions, checklist: checklist)
        #expect(sheet.automatic.map(\.title) == ["검색", "분류"])
        #expect(sheet.manual.map(\.title) == ["키보드 입력"])
        #expect(sheet.pending.isEmpty)
        #expect(sheet.failCount == 1)
    }

    @Test func QA지를_이어서_채우면_본_것은_채워지고_남은_것만_손으로_본다() throws {
        try ClaudeQASeeder.record(run(start: .now.addingTimeInterval(-3600)), app: app, in: context)
        let checklist = SessionRecorder.drafts(defaultItems: [], app: app)

        let before = VersionSheet.build(version: "5.1.6", sessions: app.sortedSessions, checklist: checklist)
        #expect(before.pending.map(\.title) == ["키보드 입력"])
        #expect(before.pending.first?.note == "실기기 필요")

        let model = SessionViewModel(app: app, defaultItems: [], continuingSheet: true)
        #expect(model.claudeSession == nil)
        #expect(model.carriedCount == 1)
        #expect(model.unansweredCount == 2)
        #expect(model.sections(where: { $0.carriedOutcome == nil }).flatMap(\.itemIDs).count == 2)
        #expect(!model.hasChanges)
    }

    @Test func 파일로_가져오면_스크린샷을_붙이고_같은_결과지는_두_번_넣지_않는다() throws {
        let defaults = try #require(UserDefaults(suiteName: "ClaudeQAImport-\(UUID())"))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let json = """
        {"id":"file-1","bundleID":"com.ysoup.tokenmemo","startedAt":"2026-09-29T10:00:00+09:00",
         "durationSeconds":60,"deviceModel":"Claude · 맥","osVersion":"iOS 27.0","appVersion":"5.2.0",
         "results":[{"title":"검색","outcome":"pass","note":"통과","screenshot":"shot-1"},
                    {"title":"분류","outcome":"na","note":"해당 없음","screenshotBase64":"\(png.base64EncodedString())"},
                    {"title":"키보드 입력","note":"실기기 필요"}]}
        """
        let jsonURL = folder.appendingPathComponent("claude-qa-file-1.json")
        try Data(json.utf8).write(to: jsonURL)
        let pngURL = folder.appendingPathComponent("shot-1.png")
        try png.write(to: pngURL)

        let first = ClaudeQASeeder.importFiles([jsonURL, pngURL], into: context, defaults: defaults)
        #expect(first.imported == ["클립키보드 v5.2.0"])
        let session = try #require(app.sortedSessions.first { $0.claudeRunID == "file-1" })
        #expect(session.sortedResults.allSatisfy { $0.screenshot == png })
        #expect(session.uncheckedNotes == ["키보드 입력": "실기기 필요"])

        let again = ClaudeQASeeder.importFiles([jsonURL], into: context, defaults: defaults)
        #expect(again.imported.isEmpty)
        #expect(again.duplicates == 1)
        #expect(app.sortedSessions.filter { $0.claudeRunID == "file-1" }.count == 1)
    }

    @Test func 목록에_없는_앱의_결과지는_알려_준다() throws {
        let defaults = try #require(UserDefaults(suiteName: "ClaudeQAImport-\(UUID())"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("claude-qa-\(UUID()).json")
        try Data("""
        {"id":"x","bundleID":"com.example.none","startedAt":"2026-09-29T10:00:00+09:00","durationSeconds":1,
         "deviceModel":"","osVersion":"","appVersion":"1.0","results":[]}
        """.utf8).write(to: url)
        let summary = ClaudeQASeeder.importFiles([url], into: context, defaults: defaults)
        #expect(summary.unknownApps == ["com.example.none"])
        #expect(summary.imported.isEmpty)
    }
}
