import Foundation
import Observation

enum AppTab: String, Hashable {
    case today, apps, issues, settings
}

struct SessionRoute: Identifiable, Hashable {
    let appID: UUID
    var id: UUID { appID }
}

@MainActor
@Observable
final class Router {
    static let shared = Router()

    private let defaults: UserDefaults

    /// 마지막으로 보던 탭. 앱을 껐다 켜도 그 자리에서 이어 본다.
    var selectedTab: AppTab {
        didSet { defaults.set(selectedTab.rawValue, forKey: SettingsKey.lastTab) }
    }

    /// 열려 있는 QA 세션. 앱이 죽어도 다시 열리도록 어느 앱이었는지 적어 둔다.
    var activeSession: SessionRoute? {
        didSet {
            if let activeSession {
                defaults.set(activeSession.appID.uuidString, forKey: SettingsKey.openSessionAppID)
            } else {
                defaults.removeObject(forKey: SettingsKey.openSessionAppID)
            }
        }
    }

    init(defaults: UserDefaults = .shared) {
        self.defaults = defaults
        self.selectedTab = AppTab(rawValue: defaults.string(forKey: SettingsKey.lastTab) ?? "") ?? .today
        if let raw = defaults.string(forKey: SettingsKey.openSessionAppID), let id = UUID(uuidString: raw) {
            self.activeSession = SessionRoute(appID: id)
        }
    }

    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .session(let id):
            // 위젯·알림으로 들어오면 어느 탭에 있었든 오늘에서 시작한다.
            startSession(id, movingToToday: true)
        case .today:
            selectedTab = .today
        }
    }

    /// 앱 탭에서 시작했으면 그 탭에 그대로 둔다. 세션을 닫았을 때 보던 자리로 돌아오도록.
    func startSession(_ appID: UUID, movingToToday: Bool = false) {
        if movingToToday { selectedTab = .today }
        guard activeSession?.appID != appID else { return }
        activeSession = SessionRoute(appID: appID)
    }
}
