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
            startSession(id)
        case .today:
            selectedTab = .today
        }
    }

    func startSession(_ appID: UUID) {
        selectedTab = .today
        guard activeSession?.appID != appID else { return }
        activeSession = SessionRoute(appID: appID)
    }
}
