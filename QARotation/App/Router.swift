import Foundation
import Observation
import SwiftData

enum AppTab: String, Hashable {
    case today, apps, issues, settings
}

struct SessionRoute: Identifiable, Hashable {
    let appID: UUID
    /// 버전 QA지를 이어서 채우는 세션. 그 버전에서 이미 본 결과를 미리 채워 연다.
    var continuesSheet = false
    var id: UUID { appID }
}

@MainActor
@Observable
final class Router {
    static let shared = Router()

    private let defaults: UserDefaults

    /// 앱을 새로 켜면 늘 오늘 탭에서 시작한다. 켤 때마다 다른 자리에 떨어지면 어디였는지 헷갈린다.
    var selectedTab: AppTab = .today

    /// 열려 있는 QA 세션. 앱이 죽어도 다시 열리도록 어느 앱이었는지 적어 둔다.
    var activeSession: SessionRoute? {
        didSet {
            if let activeSession {
                defaults.set(activeSession.appID.uuidString, forKey: SettingsKey.openSessionAppID)
                defaults.set(activeSession.continuesSheet, forKey: SettingsKey.openSessionContinuesSheet)
            } else {
                defaults.removeObject(forKey: SettingsKey.openSessionAppID)
                defaults.removeObject(forKey: SettingsKey.openSessionContinuesSheet)
            }
        }
    }

    init(defaults: UserDefaults = .shared) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: SettingsKey.openSessionAppID), let id = UUID(uuidString: raw) {
            self.activeSession = SessionRoute(appID: id, continuesSheet: defaults.bool(forKey: SettingsKey.openSessionContinuesSheet))
        }
    }

    /// 맥에서 받은 결과지 파일은 가져오고, 나머지는 딥링크로 본다.
    func open(_ url: URL, importer: ImportController, context: ModelContext) {
        if url.isFileURL {
            importer.importClaudeResults([url], context: context)
            selectedTab = .today
        } else {
            handle(url)
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
    func startSession(_ appID: UUID, movingToToday: Bool = false, continuingSheet: Bool = false) {
        if movingToToday { selectedTab = .today }
        guard activeSession?.appID != appID else { return }
        activeSession = SessionRoute(appID: appID, continuesSheet: continuingSheet)
    }
}
