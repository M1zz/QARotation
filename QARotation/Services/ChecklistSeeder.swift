import Foundation
import SwiftData

enum DefaultChecklist {
    static let items: [(ChecklistCategory, String)] = [
        (.stability, "크래시 없이 실행된다"),
        (.stability, "핵심 흐름을 끝까지 마칠 수 있다"),
        (.monetization, "구매 화면이 뜬다"),
        (.monetization, "구매 복원이 된다"),
        (.appearance, "다크 모드에서 자연스럽다"),
        (.appearance, "가장 큰 글자 크기에서도 안 깨진다"),
        (.appearance, "작은 화면(SE)에서 레이아웃이 맞다"),
        (.accessibility, "메인 화면을 VoiceOver로 쓸 수 있다"),
        (.platform, "최신 iOS에서 잘 동작한다"),
        (.platform, "지원 종료 API 경고가 보이지 않는다"),
        (.store, "스크린샷과 설명이 지금 앱과 맞다"),
    ]
}

@MainActor
enum ChecklistSeeder {
    /// 처음 한 번만 넣는다. 사용자가 다 지워도 다시 채우지 않는다.
    static func seedIfNeeded(_ context: ModelContext, defaults: UserDefaults = .shared) {
        guard !defaults.bool(forKey: SettingsKey.didSeedChecklist) else { return }
        restoreMissing(context)
        defaults.set(true, forKey: SettingsKey.didSeedChecklist)
    }

    /// 기본 항목 중 제목이 없는 것만 다시 넣는다.
    static func restoreMissing(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.isDefault }))) ?? []
        let titles = Set(existing.map(\.title))
        var order = (existing.map(\.order).max() ?? -1) + 1
        for (category, title) in DefaultChecklist.items where !titles.contains(title) {
            context.insert(ChecklistItem(title: title, category: category, order: order, isDefault: true))
            order += 1
        }
        try? context.save()
    }
}

/// 카탈로그(`AppChecklistCatalog`)에 있는 앱 전용 항목을 넣는다.
/// 한 번 넣은 제목은 App Group UserDefaults에 적어 두고 다시 넣지 않는다.
/// 그래서 사용자가 지운 항목은 돌아오지 않고, 카탈로그에 새로 적은 항목만 다음 실행에 들어간다.
@MainActor
enum AppChecklistSeeder {
    /// 아직 한 번도 넣지 않은 제목만 넣는다. 실행할 때와 가져오기 뒤에 부른다.
    static func seedNewItems(_ context: ModelContext, defaults: UserDefaults = .shared) {
        var seeded = (defaults.dictionary(forKey: SettingsKey.seededChecklistTitles) as? [String: [String]]) ?? [:]
        // 제목을 적기 전(v1.0) 버전에서 넣은 앱들. 그때 넣은 항목이 무엇이었는지는 지금 목록으로 갈음한다.
        let legacy = Set(defaults.stringArray(forKey: SettingsKey.seededAppChecklists) ?? [])
        let apps = (try? context.fetch(FetchDescriptor<TrackedApp>())) ?? []
        var changed = false

        for app in apps {
            let key = AppChecklistCatalog.key(app.bundleID)
            let catalog = AppChecklistCatalog.items(for: app.bundleID)
            guard !catalog.isEmpty else { continue }

            var known = Set(seeded[key] ?? [])
            if seeded[key] == nil, legacy.contains(key) {
                known = Set((app.extraChecklistItems ?? []).map(\.title))
            }
            let fresh = catalog.filter { !known.contains($0.1) }
            guard !fresh.isEmpty else { continue }

            insert(fresh, for: app, in: context)
            seeded[key] = Array(known.union(catalog.map(\.1))).sorted()
            changed = true
        }

        guard changed else { return }
        try? context.save()
        defaults.set(seeded, forKey: SettingsKey.seededChecklistTitles)
    }

    /// 카탈로그 항목 중 이 앱에 없는 제목의 수.
    static func missingCount(for app: TrackedApp) -> Int {
        let titles = Set((app.extraChecklistItems ?? []).map(\.title))
        return AppChecklistCatalog.items(for: app.bundleID).filter { !titles.contains($0.1) }.count
    }

    /// 카탈로그 항목 중 제목이 없는 것만 뒤에 붙인다. 지운 항목을 되살릴 때 쓴다.
    static func restoreMissing(for app: TrackedApp, in context: ModelContext) {
        let titles = Set((app.extraChecklistItems ?? []).map(\.title))
        insert(AppChecklistCatalog.items(for: app.bundleID).filter { !titles.contains($0.1) }, for: app, in: context)
        try? context.save()
    }

    private static func insert(_ items: [(ChecklistCategory, String)], for app: TrackedApp, in context: ModelContext) {
        let titles = Set((app.extraChecklistItems ?? []).map(\.title))
        var order = (app.sortedExtraItems.last?.order ?? -1) + 1
        for (category, title) in items where !titles.contains(title) {
            let item = ChecklistItem(title: title, category: category, order: order, isDefault: false)
            context.insert(item)
            item.app = app
            order += 1
        }
    }
}
