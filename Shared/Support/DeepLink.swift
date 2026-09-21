import Foundation

enum DeepLink: Equatable, Sendable {
    case session(UUID)
    case today

    static let scheme = "qarotation"

    var url: URL {
        switch self {
        case .session(let id): URL(string: "\(Self.scheme)://session/\(id.uuidString)")!
        case .today: URL(string: "\(Self.scheme)://today")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "session":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .session(id)
        case "today":
            self = .today
        default:
            return nil
        }
    }
}
