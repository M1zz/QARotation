import Foundation

/// "건너뛰기"는 QA 기록이 아니다. 오늘 하루만 기억하고, 앱과 위젯이 같은 추천을 보도록 공유 저장소에 둔다.
struct SkipStore {
    var defaults: UserDefaults = .shared
    var calendar: Calendar = .current

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    func skipped(on now: Date) -> Set<UUID> {
        guard defaults.string(forKey: SettingsKey.skipDay) == dayKey(now) else { return [] }
        let raw = defaults.stringArray(forKey: SettingsKey.skipIDs) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    /// 건너뛰고 나면 다음 추천이 누구인지는 호출한 쪽이 다시 계산한다.
    /// 후보를 전부 건너뛰었으면 목록을 비우고 방금 것만 남겨 한 바퀴 다시 돈다.
    func skip(_ id: UUID, now: Date, allCandidateIDs: Set<UUID>) {
        var current = skipped(on: now)
        current.insert(id)
        if !allCandidateIDs.isEmpty, allCandidateIDs.isSubset(of: current) {
            current = [id]
        }
        defaults.set(dayKey(now), forKey: SettingsKey.skipDay)
        defaults.set(current.map(\.uuidString), forKey: SettingsKey.skipIDs)
    }

    func clear() {
        defaults.removeObject(forKey: SettingsKey.skipIDs)
    }
}
