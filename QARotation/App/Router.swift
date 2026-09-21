import Foundation
import Observation

enum AppTab: Hashable {
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

    var selectedTab: AppTab = .today
    var activeSession: SessionRoute?

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
