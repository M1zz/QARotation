import Foundation
import SwiftData

/// 맥에서 Claude 가 먼저 돌린 QA 결과(`claude-qa-*.json`)를 세션으로 넣는다.
/// 앱에 함께 넣어 두거나 파일로 가져오고, 처음 보는 결과만 한 번 기록한다.
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
            /// 결과지 한 파일에 스크린샷까지 담을 때 쓰는 PNG base64. AirDrop 으로 보낼 때 편하다.
            let screenshotBase64: String?
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
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            do {
                return try decode(data)
            } catch {
                print("❌ [ClaudeQARuns.load] \(url.lastPathComponent): \(error)")
                return nil
            }
        }
        .sorted { $0.startedAt < $1.startedAt }
    }

    static func decode(_ data: Data) throws -> Run {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Run.self, from: data)
    }

    /// 앱에 함께 넣은 결과지에서 확인하지 못한 항목의 메모를 찾는다. 파일로 가져온 기록은 세션에 들어 있다.
    static func uncheckedNotes(runID: String, bundle: Bundle = .main) -> [String: String] {
        guard !runID.isEmpty, let run = load(bundle: bundle).first(where: { $0.id == runID }) else { return [:] }
        return uncheckedNotes(in: run)
    }

    /// 확인하지 못한 항목(결과 없음)에 남긴 메모. 제목 → 메모.
    static func uncheckedNotes(in run: Run) -> [String: String] {
        Dictionary(
            run.results.filter { $0.outcome == nil }.compactMap { entry in entry.note.map { (entry.title, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 스크린샷은 결과지 안의 base64 → 함께 고른 PNG → 앱에 넣은 PNG 순서로 찾는다.
    static func screenshot(for entry: Run.Entry, attachments: [String: Data] = [:], bundle: Bundle = .main) -> Data? {
        if let encoded = entry.screenshotBase64, let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) {
            return data
        }
        if let name = entry.screenshot, let data = attachments[name] { return data }
        return screenshot(named: entry.screenshot, bundle: bundle)
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

    static func record(
        _ run: ClaudeQARuns.Run,
        app: TrackedApp,
        in context: ModelContext,
        attachments: [String: Data] = [:],
        bundle: Bundle = .main
    ) throws {
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
                screenshot: ClaudeQARuns.screenshot(for: entry, attachments: attachments, bundle: bundle)
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
        session.uncheckedNotes = ClaudeQARuns.uncheckedNotes(in: run)
        try context.save()
    }

    struct ImportSummary: Equatable {
        /// 넣은 결과지. "앱 이름 v버전".
        var imported: [String] = []
        var duplicates = 0
        /// 목록에 없는 앱의 번들 ID.
        var unknownApps: [String] = []
        /// 읽지 못한 파일 이름.
        var unreadable: [String] = []
    }

    /// 파일 앱·AirDrop 으로 받은 결과지를 넣는다. PNG 를 함께 고르면 결과지의 스크린샷 이름과 맞춰 붙인다.
    /// 이미 넣은 결과지(같은 id)는 다시 넣지 않는다.
    static func importFiles(_ urls: [URL], into context: ModelContext, defaults: UserDefaults = .shared) -> ImportSummary {
        var summary = ImportSummary()
        var attachments: [String: Data] = [:]
        var runs: [ClaudeQARuns.Run] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                summary.unreadable.append(url.lastPathComponent)
                continue
            }
            if url.pathExtension.lowercased() == "png" {
                attachments[url.deletingPathExtension().lastPathComponent] = data
                continue
            }
            do {
                runs.append(try ClaudeQARuns.decode(data))
            } catch {
                print("❌ [ClaudeQASeeder.importFiles] \(url.lastPathComponent): \(error)")
                summary.unreadable.append(url.lastPathComponent)
            }
        }

        var seeded = Set(defaults.stringArray(forKey: SettingsKey.seededClaudeRuns) ?? [])
        let apps = (try? context.fetch(FetchDescriptor<TrackedApp>())) ?? []
        let existingRuns = Set(((try? context.fetch(FetchDescriptor<QASession>())) ?? []).map(\.claudeRunID))
        for run in runs.sorted(by: { $0.startedAt < $1.startedAt }) {
            if seeded.contains(run.id) || existingRuns.contains(run.id) {
                summary.duplicates += 1
                continue
            }
            let key = run.bundleID.lowercased()
            guard let app = apps.first(where: { $0.bundleID.lowercased() == key }) else {
                summary.unknownApps.append(run.bundleID)
                continue
            }
            do {
                try record(run, app: app, in: context, attachments: attachments)
                seeded.insert(run.id)
                summary.imported.append("\(app.name) v\(run.appVersion)")
            } catch {
                print("❌ [ClaudeQASeeder.importFiles] \(run.id): \(error)")
                summary.unreadable.append(run.id)
            }
        }
        defaults.set(seeded.sorted(), forKey: SettingsKey.seededClaudeRuns)
        return summary
    }
}

extension QASession {
    /// Claude 가 확인하지 못한 항목의 이유. 예전에 앱에 넣은 결과지는 세션에 없어서 결과지에서 다시 찾는다.
    var claudeUncheckedNotes: [String: String] {
        guard byClaude else { return [:] }
        return uncheckedNotes.isEmpty ? ClaudeQARuns.uncheckedNotes(runID: claudeRunID) : uncheckedNotes
    }
}
