import Foundation

struct TierWeights: Sendable, Equatable {
    var high: Double = 2.0
    var normal: Double = 1.0
    var low: Double = 0.5

    static let standard = TierWeights()

    func weight(for tier: Tier) -> Double {
        switch tier {
        case .high: high
        case .normal: normal
        case .low: low
        }
    }
}

/// 로테이션 계산에 필요한 값만 떼어 낸 스냅샷. SwiftData 없이 테스트할 수 있다.
struct RotationCandidate: Sendable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let tier: Tier
    let lastQADate: Date?
    let createdAt: Date
    let isArchived: Bool
}

struct SessionStamp: Sendable, Hashable {
    let appID: UUID
    let date: Date
}

struct CycleProgress: Sendable, Equatable {
    let done: Int
    let total: Int
    let completedCycles: Int
}

enum Rotation {
    static let overdueThresholdDays = 21

    /// 달력 날짜 기준 경과 일수. 어제 밤 11시에 했으면 오늘은 1일.
    static func daysSince(_ date: Date, now: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: date)
        let to = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    /// 한 번도 안 한 앱은 점수가 없다(항상 맨 앞).
    static func score(for candidate: RotationCandidate, now: Date, weights: TierWeights, calendar: Calendar = .current) -> Double? {
        guard let last = candidate.lastQADate else { return nil }
        return Double(daysSince(last, now: now, calendar: calendar)) * weights.weight(for: candidate.tier)
    }

    /// 보관된 앱을 뺀 추천 순서.
    /// 1) 한 번도 안 한 앱: 최근에 추가된 것 먼저 → 등급 → 이름
    /// 2) 나머지: 점수 높은 것 → 오래된 것 → 이름
    static func ranked(
        _ candidates: [RotationCandidate],
        now: Date,
        weights: TierWeights,
        calendar: Calendar = .current
    ) -> [RotationCandidate] {
        let active = candidates.filter { !$0.isArchived }

        let never = active
            .filter { $0.lastQADate == nil }
            .sorted { a, b in
                if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
                let wa = weights.weight(for: a.tier), wb = weights.weight(for: b.tier)
                if wa != wb { return wa > wb }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }

        let seen = active
            .compactMap { c -> (RotationCandidate, Double, Date)? in
                guard let last = c.lastQADate, let s = score(for: c, now: now, weights: weights, calendar: calendar) else { return nil }
                return (c, s, last)
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                if a.2 != b.2 { return a.2 < b.2 }
                return a.0.name.localizedStandardCompare(b.0.name) == .orderedAscending
            }
            .map(\.0)

        return never + seen
    }

    /// 건너뛴 앱을 피해 첫 번째 후보. 전부 건너뛰었으면 처음으로 돌아간다.
    static func pick(
        from candidates: [RotationCandidate],
        now: Date,
        weights: TierWeights,
        skipped: Set<UUID> = [],
        calendar: Calendar = .current
    ) -> RotationCandidate? {
        let order = ranked(candidates, now: now, weights: weights, calendar: calendar)
        return order.first { !skipped.contains($0.id) } ?? order.first
    }

    static func overdueCount(
        _ candidates: [RotationCandidate],
        now: Date,
        threshold: Int = overdueThresholdDays,
        calendar: Calendar = .current
    ) -> Int {
        candidates.filter { c in
            guard !c.isArchived, let last = c.lastQADate else { return false }
            return daysSince(last, now: now, calendar: calendar) > threshold
        }.count
    }

    static func neverQACount(_ candidates: [RotationCandidate]) -> Int {
        candidates.filter { !$0.isArchived && $0.lastQADate == nil }.count
    }

    /// 사이클 = 지금 로테이션에 있는 앱을 전부 한 번씩 QA 하는 한 바퀴.
    /// 기록을 시간순으로 훑으며 모든 앱이 채워지면 다음 사이클로 넘어간다.
    static func cycleProgress(sessions: [SessionStamp], activeAppIDs: Set<UUID>) -> CycleProgress {
        guard !activeAppIDs.isEmpty else { return CycleProgress(done: 0, total: 0, completedCycles: 0) }
        var covered = Set<UUID>()
        var completed = 0
        for stamp in sessions.sorted(by: { $0.date < $1.date }) where activeAppIDs.contains(stamp.appID) {
            covered.insert(stamp.appID)
            if covered.count == activeAppIDs.count {
                completed += 1
                covered.removeAll()
            }
        }
        return CycleProgress(done: covered.count, total: activeAppIDs.count, completedCycles: completed)
    }
}
