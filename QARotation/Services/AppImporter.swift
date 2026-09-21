import Foundation
import SwiftData
import UIKit

struct ImportSummary: Sendable, Equatable {
    var inserted = 0
    var updated = 0
    var unchanged = 0

    var total: Int { inserted + updated + unchanged }
}

/// 기존 앱과 스토어 결과를 짝짓는 계획. 순수 함수라 테스트하기 쉽다.
/// 지우는 동작은 아예 없다 — 스토어에서 내려간 앱도 로컬 기록은 남는다.
enum ImportPlan {
    struct ExistingKey: Sendable, Equatable {
        let id: UUID
        let appStoreID: String
        let bundleID: String
    }

    struct Result: Sendable, Equatable {
        var matches: [UUID: StoreApp] = [:]
        var inserts: [StoreApp] = []
    }

    static func make(existing: [ExistingKey], fetched: [StoreApp]) -> Result {
        var result = Result()
        var claimed = Set<UUID>()
        for app in fetched {
            let match = existing.first { !claimed.contains($0.id) && !$0.appStoreID.isEmpty && $0.appStoreID == app.appStoreID }
                ?? existing.first { !claimed.contains($0.id) && !$0.bundleID.isEmpty && $0.bundleID == app.bundleID }
            if let match {
                claimed.insert(match.id)
                result.matches[match.id] = app
            } else {
                result.inserts.append(app)
            }
        }
        return result
    }
}

@MainActor
enum AppImporter {
    /// 스토어가 주인인 값(이름·번들 ID·아이콘·버전·플랫폼)만 덮어쓴다.
    /// 등급·URL 스킴·메모·보관 여부·전용 체크 항목은 건드리지 않는다.
    @discardableResult
    static func apply(_ fetched: [StoreApp], to context: ModelContext, now: Date = .now) throws -> ImportSummary {
        let existing = try context.fetch(FetchDescriptor<TrackedApp>())
        let plan = ImportPlan.make(
            existing: existing.map { .init(id: $0.id, appStoreID: $0.appStoreID, bundleID: $0.bundleID) },
            fetched: fetched
        )

        var summary = ImportSummary()
        for app in existing {
            guard let store = plan.matches[app.id] else { continue }
            if update(app, from: store) { summary.updated += 1 } else { summary.unchanged += 1 }
        }
        // 같은 가져오기로 들어온 앱은 같은 시각을 받아, "새로 들어온 앱"끼리는 등급·이름 순으로 정렬된다.
        for store in plan.inserts {
            let app = TrackedApp(
                name: store.name,
                appStoreID: store.appStoreID,
                bundleID: store.bundleID,
                iconURL: store.iconURL,
                currentVersion: store.version,
                platforms: store.platforms,
                createdAt: now
            )
            context.insert(app)
            summary.inserted += 1
        }
        try context.save()
        return summary
    }

    private static func update(_ app: TrackedApp, from store: StoreApp) -> Bool {
        var changed = false
        func assign<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<TrackedApp, T>, _ value: T) {
            if app[keyPath: keyPath] != value {
                app[keyPath: keyPath] = value
                changed = true
            }
        }
        assign(\.appStoreID, store.appStoreID)
        assign(\.name, store.name)
        if !store.bundleID.isEmpty { assign(\.bundleID, store.bundleID) }
        assign(\.currentVersion, store.version)
        assign(\.platformsRaw, store.platforms.map(\.rawValue))
        if !store.iconURL.isEmpty, app.iconURL != store.iconURL {
            app.iconURL = store.iconURL
            app.iconData = nil // 새 아이콘을 다시 받도록
            changed = true
        }
        return changed
    }

    /// 아이콘을 받아 위젯에서도 쓸 수 있게 작게 줄여 저장한다.
    static func downloadMissingIcons(in context: ModelContext) async throws {
        let apps = try context.fetch(FetchDescriptor<TrackedApp>())
        let requests = apps.compactMap { app -> IconDownloader.Request? in
            guard app.iconData == nil, let url = URL(string: app.iconURL), !app.iconURL.isEmpty else { return nil }
            return .init(appID: app.id, url: url)
        }
        guard !requests.isEmpty else { return }
        let icons = await IconDownloader.download(requests)
        for app in apps {
            if let data = icons[app.id] { app.iconData = data }
        }
        try context.save()
    }
}

enum IconDownloader {
    struct Request: Sendable {
        let appID: UUID
        let url: URL
    }

    static let pixelSize: CGFloat = 180

    static func download(_ requests: [Request], session: URLSession = .shared) async -> [UUID: Data] {
        await withTaskGroup(of: (UUID, Data?).self) { group in
            for request in requests {
                group.addTask {
                    guard let (data, _) = try? await session.data(from: request.url) else { return (request.appID, nil) }
                    return (request.appID, downscaled(data))
                }
            }
            var result: [UUID: Data] = [:]
            for await (id, data) in group {
                if let data { result[id] = data }
            }
            return result
        }
    }

    /// 위젯은 큰 이미지를 못 띄우므로 180px PNG 로 줄인다.
    static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: pixelSize, height: pixelSize)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
