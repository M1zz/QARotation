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

    @Test func 문구를_고친_항목은_기기에서도_바뀌고_뺀_항목은_지워진다() throws {
        let bundleID = "com.leeo.JuJob"
        let app = insertApp(bundleID: bundleID)
        let key = AppChecklistCatalog.key(bundleID)
        let renamed = try #require(AppChecklistCatalog.renamedTitles[key]?.first)
        let removedTitle = try #require(AppChecklistCatalog.removedTitles[key]?.first)
        for (index, title) in [renamed.key, removedTitle].enumerated() {
            let item = ChecklistItem(title: title, category: .custom, order: index, isDefault: false)
            context.insert(item)
            item.app = app
        }
        try context.save()
        defaults.set([key: [renamed.key, removedTitle]], forKey: SettingsKey.seededChecklistTitles)

        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        let titles = app.sortedExtraItems.map(\.title)
        #expect(titles.contains(renamed.value))
        #expect(!titles.contains(renamed.key))
        #expect(!titles.contains(removedTitle))
        #expect(app.sortedExtraItems.allSatisfy { !$0.steps.isEmpty })

        // 두 번째 실행에서 지운 항목이 되살아나지 않는다.
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)
        #expect(!app.sortedExtraItems.map(\.title).contains(removedTitle))
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

@Suite("코드로 확인할 항목")
@MainActor
struct CodeTestListTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        context = container.mainContext
    }

    @Test func 카탈로그에_유닛과_UI_항목이_들어_있다() {
        let all = AppChecklistCatalog.itemsByBundleID.values.flatMap { $0 }
        #expect(all.contains { $0.verification == .unit })
        #expect(all.contains { $0.verification == .ui })
        #expect(all.contains { $0.verification == .manual })
        #expect(Verification.manual.badge == nil)
        #expect(Verification.unit.isAutomatable)
    }

    @Test func 넣을_때_카탈로그의_확인_방법이_따라온다() throws {
        let defaults = UserDefaults(suiteName: "CodeTestListTests-\(UUID().uuidString)")!
        let app = TrackedApp(name: "클립키보드", bundleID: "com.Ysoup.TokenMemo")
        context.insert(app)
        try context.save()
        AppChecklistSeeder.seedNewItems(context, defaults: defaults)

        let catalog = AppChecklistCatalog.items(for: app.bundleID)
        let expected = Dictionary(catalog.map { ($0.title, $0.verification) }, uniquingKeysWith: { first, _ in first })
        #expect(app.sortedExtraItems.allSatisfy { expected[$0.title] == $0.verification })
    }

    @Test func 복사한_글에는_손으로_하는_항목이_빠진다() throws {
        let app = TrackedApp(name: "테스트앱", bundleID: "com.example.app", currentVersion: "1.2")
        context.insert(app)
        let items: [(String, Verification)] = [("손으로 본다", .manual), ("로직이 맞다", .unit), ("화면이 바뀐다", .ui)]
        for (index, (title, verification)) in items.enumerated() {
            let item = ChecklistItem(
                title: title,
                steps: "\(title) 단계",
                category: .custom,
                verification: verification,
                order: index,
                isDefault: false
            )
            context.insert(item)
            item.app = app
        }
        try context.save()

        let text = CodeTestList.text(for: app)
        #expect(text.contains("로직이 맞다"))
        #expect(text.contains("화면이 바뀐다"))
        #expect(!text.contains("손으로 본다"))
        #expect(text.contains("유닛 테스트 (1개)"))
        #expect(text.contains("UI 테스트 (1개)"))
        #expect(text.contains("테스트 중인 버전: 1.2"))
    }
}

@Suite("기본 항목의 앱별 단계")
@MainActor
struct DefaultStepsByAppTests {
    @Test func 적어_둔_단계는_모두_기본_항목_제목이다() {
        let titles = Set(DefaultChecklist.items.map(\.title))
        for (bundleID, steps) in AppChecklistCatalog.defaultStepsByBundleID {
            for (title, text) in steps {
                #expect(titles.contains(title), "\(bundleID): \(title)")
                #expect(!text.isEmpty)
                // 두루뭉술한 원래 문구가 그대로 남아 있으면 고친 뜻이 없다.
                #expect(!text.contains("가장 흔한 일 하나"), "\(bundleID): \(title)")
            }
        }
    }

    @Test func 세션에서_그_앱의_단계로_바뀐다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let app = TrackedApp(name: "클립키보드", bundleID: "com.Ysoup.TokenMemo")
        context.insert(app)
        let title = "핵심 흐름을 끝까지 마칠 수 있다"
        let generic = try #require(DefaultChecklist.items.first { $0.title == title })
        let item = ChecklistItem(title: title, steps: generic.steps, category: generic.category, order: 0, isDefault: true)
        context.insert(item)
        try context.save()

        let drafts = SessionRecorder.drafts(defaultItems: [item], app: app)
        let mine = try #require(drafts.first { $0.title == title })
        let expected = try #require(AppChecklistCatalog.defaultSteps(for: app.bundleID)[title])
        #expect(mine.steps == expected)
        #expect(mine.steps != generic.steps)
    }

    @Test func 적어_두지_않은_앱은_기본_문구를_쓴다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let app = TrackedApp(name: "모르는 앱", bundleID: "com.example.unknown")
        context.insert(app)
        let generic = try #require(DefaultChecklist.items.first)
        let item = ChecklistItem(title: generic.title, steps: generic.steps, category: generic.category, order: 0, isDefault: true)
        context.insert(item)
        try context.save()

        let drafts = SessionRecorder.drafts(defaultItems: [item], app: app)
        #expect(drafts.first?.steps == generic.steps)
    }
}
