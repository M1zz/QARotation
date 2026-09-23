import Foundation

enum SettingsKey {
    static let artistID = "artistID"
    static let storefronts = "storefronts"
    static let timerMinutes = "timerMinutes"
    static let weightHigh = "tierWeightHigh"
    static let weightNormal = "tierWeightNormal"
    static let weightLow = "tierWeightLow"
    static let remindersEnabled = "breakRemindersEnabled"
    static let breakTimes = "breakTimes"
    static let didSeedChecklist = "didSeedChecklist"
    /// v1.0에서 쓰던 "이 앱은 넣었음" 목록. 지금은 아래 제목 목록으로 갈음한다.
    static let seededAppChecklists = "seededAppChecklists"
    static let seededChecklistTitles = "seededChecklistTitles"
    static let didSeedBundledApps = "didSeedBundledApps"
    /// 열려 있던 QA 세션의 앱. 앱이 죽어도 하던 QA로 돌아가려고 적어 둔다.
    static let openSessionAppID = "openSessionAppID"
    static let skipDay = "skipDay"
    static let skipIDs = "skipIDs"
}

enum SettingsDefault {
    /// hyunho lee 개발자 계정. 클립키보드(1543660502) 조회 결과에서 확인.
    static let artistID = "1502508537"
    /// 스토어마다 올라간 앱이 조금씩 달라서(한국 45 · 미국 46) 둘을 합친다.
    static let storefronts = "kr,us"
    static let timerMinutes = 7
}

enum AppSettings {
    static func registerDefaults(_ defaults: UserDefaults = .shared) {
        defaults.register(defaults: [
            SettingsKey.artistID: SettingsDefault.artistID,
            SettingsKey.storefronts: SettingsDefault.storefronts,
            SettingsKey.timerMinutes: SettingsDefault.timerMinutes,
            SettingsKey.weightHigh: TierWeights.standard.high,
            SettingsKey.weightNormal: TierWeights.standard.normal,
            SettingsKey.weightLow: TierWeights.standard.low,
            SettingsKey.remindersEnabled: false,
        ])
    }

    static func tierWeights(_ defaults: UserDefaults = .shared) -> TierWeights {
        TierWeights(
            high: defaults.double(forKey: SettingsKey.weightHigh),
            normal: defaults.double(forKey: SettingsKey.weightNormal),
            low: defaults.double(forKey: SettingsKey.weightLow)
        )
    }

    static func artistID(_ defaults: UserDefaults = .shared) -> String {
        (defaults.string(forKey: SettingsKey.artistID) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func storefronts(_ defaults: UserDefaults = .shared) -> [String] {
        (defaults.string(forKey: SettingsKey.storefronts) ?? "")
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
    }

    static func timerMinutes(_ defaults: UserDefaults = .shared) -> Int {
        max(1, defaults.integer(forKey: SettingsKey.timerMinutes))
    }
}
