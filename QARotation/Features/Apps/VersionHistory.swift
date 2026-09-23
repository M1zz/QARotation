import Foundation

/// QA 기록을 테스트한 버전별로 묶는다. 앱 상세와 테스트에서 함께 쓴다.
enum VersionHistory {
    struct Group: Identifiable {
        let version: String
        let sessions: [QASession]
        var id: String { version }
        /// 버전을 적지 않고 QA한 기록도 있으므로 빈 값을 따로 부른다.
        var title: String { version.isEmpty ? "버전 모름" : "v\(version)" }
    }

    /// 최근에 QA한 버전이 위에 온다. 묶음 안에서는 최신 기록이 위다.
    static func groups(of sessions: [QASession]) -> [Group] {
        let sorted = sessions.sorted { $0.date > $1.date }
        var order: [String] = []
        var byVersion: [String: [QASession]] = [:]
        for session in sorted {
            let version = session.appVersion.trimmingCharacters(in: .whitespaces)
            if byVersion[version] == nil { order.append(version) }
            byVersion[version, default: []].append(session)
        }
        return order.map { Group(version: $0, sessions: byVersion[$0] ?? []) }
    }
}
