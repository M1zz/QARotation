import Foundation
import SwiftData
import WidgetKit

/// 오늘의 추천이 바뀔 수 있는 일(세션 완료·건너뛰기·가져오기·설정 변경) 뒤에 부른다.
/// 위젯과 쉬는 시간 알림 문구를 새 추천에 맞춘다.
@MainActor
enum PickChangeCoordinator {
    static func pickDidChange(context: ModelContext) {
        WidgetCenter.shared.reloadAllTimelines()

        let pick = (try? PickResolver.currentPick(in: context)).map { PickSummary(appID: $0.id, name: $0.name) }
        let defaults = UserDefaults.shared
        let minutes = AppSettings.timerMinutes(defaults)
        let enabled = defaults.bool(forKey: SettingsKey.remindersEnabled)
        let times = BreakTimeStore.load(defaults)
        Task {
            await NotificationScheduler.reschedule(pick: pick, minutes: minutes, enabled: enabled, times: times)
        }
    }
}
