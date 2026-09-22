import Foundation
import SwiftData

enum DefaultChecklist {
    /// (분류, 제목, 확인하는 단계)
    static let items: [(ChecklistCategory, String, String)] = [
        (.stability, "크래시 없이 실행된다",
         "앱 전환기에서 앱을 밀어 끈다 → 홈에서 아이콘을 누른다 → 3초 안에 첫 화면이 뜨고 흰 화면이나 튕김이 없다"),
        (.stability, "핵심 흐름을 끝까지 마칠 수 있다",
         "이 앱을 쓰는 가장 흔한 일 하나를 고른다 → 처음부터 끝까지 해 본다 → 결과가 저장되고 앱을 다시 열어도 남아 있다"),
        (.monetization, "구매 화면이 뜬다",
         "설정이나 잠긴 기능에서 구매를 누른다 → 가격과 기간이 보인다 → 빈칸·오류 문구·로딩만 도는 화면이 아니다"),
        (.monetization, "구매 복원이 된다",
         "구매 화면에서 복원을 누른다 → Apple 계정 확인을 넘긴다 → 결과 안내가 뜨고 잠금이 풀리거나 살 게 없다고 알려 준다"),
        (.appearance, "다크 모드에서 자연스럽다",
         "제어센터나 설정에서 다크 모드로 바꾼다 → 주요 화면을 한 바퀴 넘겨 본다 → 흰 판·검은 글씨가 뒤섞이거나 안 보이는 글자가 없다"),
        (.appearance, "가장 큰 글자 크기에서도 안 깨진다",
         "설정 ▸ 손쉬운 사용 ▸ 텍스트 크기에서 가장 크게 올린다 → 주요 화면을 본다 → 글자가 잘리거나 버튼이 화면 밖으로 나가지 않는다"),
        (.appearance, "작은 화면(SE)에서 레이아웃이 맞다",
         "SE나 미니 시뮬레이터로 연다 → 주요 화면을 본다 → 아래 버튼이 가려지거나 글자가 겹치지 않는다"),
        (.accessibility, "메인 화면을 VoiceOver로 쓸 수 있다",
         "설정 ▸ 손쉬운 사용에서 VoiceOver를 켠다 → 첫 화면을 오른쪽으로 쓸어 넘긴다 → 버튼 이름이 읽히고 핵심 동작을 두 번 탭으로 할 수 있다"),
        (.platform, "최신 iOS에서 잘 동작한다",
         "최신 iOS 기기나 시뮬레이터로 연다 → 주요 화면과 위젯을 본다 → 화면이 어긋나거나 동작이 멈추는 곳이 없다"),
        (.platform, "지원 종료 API 경고가 보이지 않는다",
         "Xcode에서 빌드한다 → 경고 목록을 연다 → deprecated 경고가 없다"),
        (.store, "스크린샷과 설명이 지금 앱과 맞다",
         "App Store에서 이 앱 페이지를 연다 → 스크린샷과 설명을 지금 화면과 견준다 → 없어진 기능이나 옛 화면이 없다"),
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

    /// 이미 넣어 둔 기본 항목에 확인 단계가 비어 있으면 채운다. v1.0에서 받은 기기를 위한 것이다.
    static func fillMissingSteps(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.isDefault }))) ?? []
        let stepsByTitle = Dictionary(uniqueKeysWithValues: DefaultChecklist.items.map { ($0.1, $0.2) })
        var changed = false
        for item in existing where item.steps.isEmpty {
            guard let steps = stepsByTitle[item.title], !steps.isEmpty else { continue }
            item.steps = steps
            changed = true
        }
        if changed { try? context.save() }
    }

    /// 기본 항목 중 제목이 없는 것만 다시 넣는다.
    static func restoreMissing(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.isDefault }))) ?? []
        let titles = Set(existing.map(\.title))
        var order = (existing.map(\.order).max() ?? -1) + 1
        for (category, title, steps) in DefaultChecklist.items where !titles.contains(title) {
            context.insert(ChecklistItem(title: title, steps: steps, category: category, order: order, isDefault: true))
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
            let stepsByTitle = Dictionary(catalog.map { ($0.1, $0.2) }, uniquingKeysWith: { first, _ in first })
            for item in app.extraChecklistItems ?? [] where item.steps.isEmpty {
                if let steps = stepsByTitle[item.title], !steps.isEmpty {
                    item.steps = steps
                    changed = true
                }
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

    private static func insert(_ items: [(ChecklistCategory, String, String)], for app: TrackedApp, in context: ModelContext) {
        let titles = Set((app.extraChecklistItems ?? []).map(\.title))
        var order = (app.sortedExtraItems.last?.order ?? -1) + 1
        for (category, title, steps) in items where !titles.contains(title) {
            let item = ChecklistItem(title: title, steps: steps, category: category, order: order, isDefault: false)
            context.insert(item)
            item.app = app
            order += 1
        }
    }
}
