import Foundation
import SwiftData

/// Claude 가 먼저 돌린 QA 결과(`claude-qa-*.json`)를 세션으로 넣는다.
/// 앱에 함께 넣어 두고, 처음 보는 결과만 한 번 기록한다.
/// 로테이션의 "마지막 QA"는 올리지 않는다. 사람이 이어서 봐야 끝난 것으로 친다.
enum ClaudeQARuns {
    struct Run: Decodable {
        struct Entry: Decodable {
            let title: String
            /// pass · fail · na. 없으면 Claude 가 확인하지 못한 항목이다.
            let outcome: String?
            let note: String?
            /// 함께 넣어 둔 PNG 파일 이름(확장자 없이).
            let screenshot: String?
        }

        let id: String
        let bundleID: String
        let startedAt: Date
        let durationSeconds: Int
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        let results: [Entry]
    }

    static func load(bundle: Bundle = .main) -> [Run] {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("claude-qa-") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                return try decoder.decode(Run.self, from: data)
            } catch {
                print("❌ [ClaudeQARuns.load] \(url.lastPathComponent): \(error)")
                return nil
            }
        }
        .sorted { $0.startedAt < $1.startedAt }
    }

    /// 확인하지 못한 항목(결과 없음)에 남긴 메모. 제목 → 메모.
    static func uncheckedNotes(runID: String, bundle: Bundle = .main) -> [String: String] {
        guard !runID.isEmpty, let run = load(bundle: bundle).first(where: { $0.id == runID }) else { return [:] }
        return Dictionary(
            run.results.filter { $0.outcome == nil }.compactMap { entry in entry.note.map { (entry.title, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static func screenshot(named name: String?, bundle: Bundle = .main) -> Data? {
        guard let name, let url = bundle.url(forResource: name, withExtension: "png") else { return nil }
        return try? Data(contentsOf: url)
    }
}

@MainActor
enum ClaudeQASeeder {
    /// 아직 넣지 않은 결과만 넣는다. 사용자가 기록을 지워도 다시 넣지 않는다.
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults = .shared, bundle: Bundle = .main) {
        var seeded = Set(defaults.stringArray(forKey: SettingsKey.seededClaudeRuns) ?? [])
        let apps = (try? context.fetch(FetchDescriptor<TrackedApp>())) ?? []
        var changed = false
        for run in ClaudeQARuns.load(bundle: bundle) where !seeded.contains(run.id) {
            let key = run.bundleID.lowercased()
            // 앱이 아직 목록에 없으면 다음 실행(가져오기 뒤)에 다시 시도한다.
            guard let app = apps.first(where: { $0.bundleID.lowercased() == key }) else { continue }
            do {
                try record(run, app: app, in: context, bundle: bundle)
                seeded.insert(run.id)
                changed = true
            } catch {
                print("❌ [ClaudeQASeeder.seedIfNeeded] \(run.id): \(error)")
            }
        }
        if changed { defaults.set(seeded.sorted(), forKey: SettingsKey.seededClaudeRuns) }
    }

    static func record(_ run: ClaudeQARuns.Run, app: TrackedApp, in context: ModelContext, bundle: Bundle = .main) throws {
        // 분류와 순서는 지금 이 앱의 체크리스트를 따른다. 없는 제목은 기타로 뒤에 붙인다.
        let items = app.sortedExtraItems
        let drafts = run.results.enumerated().map { index, entry in
            let item = items.firstIndex { $0.title == entry.title }
            return DraftResult(
                id: UUID(),
                title: entry.title,
                steps: item.map { items[$0].steps } ?? "",
                category: item.map { items[$0].category } ?? .custom,
                verification: item.map { items[$0].verification } ?? .manual,
                order: item ?? items.count + index,
                isAppSpecific: true,
                outcome: entry.outcome.flatMap(Outcome.init(rawValue:)),
                note: entry.note ?? "",
                screenshot: ClaudeQARuns.screenshot(named: entry.screenshot, bundle: bundle)
            )
        }
        let meta = SessionMeta(startedAt: run.startedAt, deviceModel: run.deviceModel, osVersion: run.osVersion, appVersion: run.appVersion)
        let session = try SessionRecorder.record(
            app: app,
            drafts: drafts,
            reverify: [:],
            meta: meta,
            byClaude: true,
            in: context,
            now: run.startedAt.addingTimeInterval(TimeInterval(run.durationSeconds))
        )
        session.claudeRunID = run.id
        try context.save()
    }
}
