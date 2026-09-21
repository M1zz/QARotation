import Foundation
import UserNotifications

struct BreakTime: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var hour: Int
    var minute: Int

    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}

enum BreakTimeStore {
    static func load(_ defaults: UserDefaults = .shared) -> [BreakTime] {
        guard let data = defaults.data(forKey: SettingsKey.breakTimes),
              let times = try? JSONDecoder().decode([BreakTime].self, from: data) else { return [] }
        return times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    static func save(_ times: [BreakTime], _ defaults: UserDefaults = .shared) {
        defaults.set(try? JSONEncoder().encode(times), forKey: SettingsKey.breakTimes)
    }
}

struct PickSummary: Sendable, Equatable {
    let appID: UUID
    let name: String
}

enum NotificationScheduler {
    static let identifierPrefix = "break-"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// 매일 반복 알림은 문구가 고정되므로, 추천이 바뀔 때마다 다시 건다.
    static func reschedule(pick: PickSummary?, minutes: Int, enabled: Bool, times: [BreakTime]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) })

        guard enabled, !times.isEmpty else { return }

        for time in times {
            let content = UNMutableNotificationContent()
            content.title = "쉬는 시간이에요"
            if let pick {
                content.body = "\(minutes)분 동안 \(pick.name) QA 해 볼까요?"
                content.userInfo = ["url": DeepLink.session(pick.appID).url.absoluteString]
            } else {
                content.body = "오늘 QA할 앱을 골라 볼까요?"
                content.userInfo = ["url": DeepLink.today.url.absoluteString]
            }
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: time.hour, minute: time.minute),
                repeats: true
            )
            let request = UNNotificationRequest(identifier: identifierPrefix + time.id.uuidString, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
