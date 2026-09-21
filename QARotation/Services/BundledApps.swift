import Foundation
import SwiftData

/// 앱에 넣어 둔 내 앱 목록(`SeedApps.json`)과 아이콘(`appicon-<번들 ID>.png`).
/// 가져오기를 누르지 않아도 처음 켜면 목록이 차 있게 하려는 것이다.
/// 스토어에 없는 앱(Externalize)도 여기 들어 있다.
enum BundledApps {
    private struct Entry: Decodable {
        let appStoreID: String
        let bundleID: String
        let name: String
        let iconURL: String
        let version: String
        let platforms: [String]
    }

    static func load(bundle: Bundle = .main) -> [StoreApp] {
        guard let url = bundle.url(forResource: "SeedApps", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries.map {
            StoreApp(
                appStoreID: $0.appStoreID,
                bundleID: $0.bundleID,
                name: $0.name,
                iconURL: $0.iconURL,
                version: $0.version,
                platforms: $0.platforms.compactMap(Platform.init(rawValue:))
            )
        }
    }

    static func icon(for bundleID: String, bundle: Bundle = .main) -> Data? {
        guard !bundleID.isEmpty,
              let url = bundle.url(forResource: "appicon-\(bundleID.lowercased())", withExtension: "png")
        else { return nil }
        return try? Data(contentsOf: url)
    }
}

@MainActor
enum BundledAppsSeeder {
    /// 처음 한 번만 넣는다. 사용자가 지운 앱은 다시 넣지 않는다.
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults = .shared, bundle: Bundle = .main) {
        guard !defaults.bool(forKey: SettingsKey.didSeedBundledApps) else { return }
        let apps = BundledApps.load(bundle: bundle)
        guard !apps.isEmpty, (try? AppImporter.apply(apps, to: context)) != nil else { return }
        fillMissingIcons(context, bundle: bundle)
        defaults.set(true, forKey: SettingsKey.didSeedBundledApps)
    }

    /// 아이콘이 없는 앱에 넣어 둔 아이콘을 채운다. 네트워크 없이도 목록과 위젯에 아이콘이 보인다.
    static func fillMissingIcons(_ context: ModelContext, bundle: Bundle = .main) {
        let apps = (try? context.fetch(FetchDescriptor<TrackedApp>())) ?? []
        for app in apps where app.iconData == nil {
            app.iconData = BundledApps.icon(for: app.bundleID, bundle: bundle)
        }
        try? context.save()
    }
}
