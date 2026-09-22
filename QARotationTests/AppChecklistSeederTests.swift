import Foundation
import SwiftData
import Testing
@testable import QARotation

@Suite("앱 전용 체크 항목 넣기")
@MainActor
struct AppChecklistSeederTests {
    let container: ModelContainer
    let context: ModelContext
    let defaults: UserDefaults

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
        defaults = UserDefaults(suiteName: "AppChecklistSeederTests-\(UUID().uuidString)")!
    }

    func insertApp(bundleID: String) -> TrackedApp {
        let app = TrackedApp(name: "앱", bundleID: bundleID)
        context.insert(app)
        return app
    }

    var catalogTitles: [String] { AppChecklistCatalog.items(for: "com.Ysoup.TokenMemo").map(\.1) }

    @Test func 카탈로그에_있는_앱에_항목을_넣는다() {
        let app = insertApp(bundleID: "com.Ysoup.TokenMemo")
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(!catalogTitles.isEmpty)
        #expect(app.sortedExtraItems.map(\.title) == catalogTitles)
        #expect(app.sortedExtraItems.allSatisfy { !$0.isDefault })
    }

    @Test func 번들_ID는_대소문자를_가리지_않는다() {
        let app = insertApp(bundleID: "com.ysoup.tokenmemo")
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(app.sortedExtraItems.map(\.title) == catalogTitles)
    }

    @Test func 카탈로그에_없는_앱은_건드리지_않는다() {
        let app = insertApp(bundleID: "com.unknown.app")
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(app.sortedExtraItems.isEmpty)
    }

    @Test func 카탈로그에_새_항목이_생기면_다음_실행에_들어간다() throws {
        let app = insertApp(bundleID: "com.Ysoup.TokenMemo")
        // v1.0에서 앞 일곱 개만 받아 둔 기기를 흉내 낸다.
        let old = Array(AppChecklistCatalog.items(for: app.bundleID).prefix(7))
        for (index, item) in old.enumerated() {
            let checklistItem = ChecklistItem(title: item.1, category: item.0, order: index, isDefault: false)
            context.insert(checklistItem)
            checklistItem.app = app
        }
        try context.save()
        defaults.set([AppChecklistCatalog.key(app.bundleID)], forKey: SettingsKey.seededAppChecklists)

        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(app.sortedExtraItems.map(\.title) == catalogTitles)
    }

    @Test func 지운_항목은_다시_채우지_않고_다시_넣기로만_돌아온다() throws {
        let app = insertApp(bundleID: "com.Ysoup.TokenMemo")
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        let first = try #require(app.sortedExtraItems.first)
        context.delete(first)
        try context.save()

        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(app.sortedExtraItems.count == catalogTitles.count - 1)
        #expect(AppChecklistSeeder.missingCount(for: app) == 1)

        AppChecklistSeeder.restoreMissing(for: app, in: context)
        #expect(Set(app.sortedExtraItems.map(\.title)) == Set(catalogTitles))
        #expect(AppChecklistSeeder.missingCount(for: app) == 0)
    }

    @Test func 사용자가_넣은_항목은_남기고_뒤에_붙인다() throws {
        let app = insertApp(bundleID: "com.Ysoup.TokenMemo")
        let mine = ChecklistItem(title: "내 항목", category: .custom, order: 0, isDefault: false)
        context.insert(mine)
        mine.app = app
        try context.save()

        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(app.sortedExtraItems.map(\.title) == ["내 항목"] + catalogTitles)
    }

    @Test func 카탈로그_제목은_앱마다_겹치지_않는다() {
        for (bundleID, items) in AppChecklistCatalog.itemsByBundleID {
            let titles = items.map(\.1)
            #expect(Set(titles).count == titles.count, "\(bundleID)")
            #expect(!items.isEmpty, "\(bundleID)")
        }
    }
}

@Suite("넣어 둔 내 앱 목록")
@MainActor
struct BundledAppsTests {
    @Test func 모든_앱에_아이콘과_전용_항목이_있다() {
        let apps = BundledApps.load()
        #expect(apps.count >= 46)
        for app in apps {
            #expect(BundledApps.icon(for: app.bundleID) != nil, "\(app.name)")
            #expect(!AppChecklistCatalog.items(for: app.bundleID).isEmpty, "\(app.name)")
        }
    }

    @Test func 처음_켜면_목록과_아이콘과_항목이_차_있다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "BundledAppsTests-\(UUID().uuidString)")!
        BundledAppsSeeder.seedIfNeeded(context, defaults: defaults)
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)

        let apps = try context.fetch(FetchDescriptor<TrackedApp>())
        #expect(apps.count == BundledApps.load().count)
        #expect(apps.allSatisfy { $0.iconData != nil && !$0.sortedExtraItems.isEmpty })
    }

    @Test func 지운_앱은_다시_넣지_않는다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "BundledAppsTests-\(UUID().uuidString)")!
        BundledAppsSeeder.seedIfNeeded(context, defaults: defaults)
        let first = try #require(try context.fetch(FetchDescriptor<TrackedApp>()).first)
        context.delete(first)
        try context.save()

        BundledAppsSeeder.seedIfNeeded(context, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<TrackedApp>()) == BundledApps.load().count - 1)
    }
}
