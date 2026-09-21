import Foundation
import SwiftData

/// 오늘의 추천을 앱과 위젯이 똑같이 계산하도록 한 곳에 둔다.
enum PickResolver {
    static func currentPick(in context: ModelContext, now: Date = .now, defaults: UserDefaults = .shared) throws -> TrackedApp? {
        let apps = try context.fetch(FetchDescriptor<TrackedApp>(predicate: #Predicate { !$0.isArchived }))
        return pick(among: apps, now: now, defaults: defaults)
    }

    static func pick(among apps: [TrackedApp], now: Date = .now, defaults: UserDefaults = .shared) -> TrackedApp? {
        let candidates = apps.map(\.rotationCandidate)
        let skipped = SkipStore(defaults: defaults).skipped(on: now)
        guard let chosen = Rotation.pick(from: candidates, now: now, weights: AppSettings.tierWeights(defaults), skipped: skipped) else {
            return nil
        }
        return apps.first { $0.id == chosen.id }
    }
}
