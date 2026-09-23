import Foundation

/// 완료를 누르기 전의 QA 진행 상태. 앱을 닫아도 이어서 할 수 있게 잠시 맡아 둔다.
/// 기록(`QASession`)은 완료해야 생긴다. 이건 저장소가 아니라 임시 보관함이다.
struct SessionDraft: Codable, Sendable, Equatable {
    var appID: UUID
    var savedAt: Date
    /// 지금까지 QA에 쓴 시간. 이어서 할 때 여기서부터 다시 센다.
    var elapsedSeconds: Int
    var deviceModel: String
    var osVersion: String
    var appVersion: String
    /// 항목 ID → 통과·실패·해당 없음
    var outcomes: [String: String]
    /// 실패 항목에 적어 둔 메모. 스크린샷은 크기 때문에 맡아 두지 않는다.
    var notes: [String: String]
    /// 이슈 ID → 고쳐졌어요·아직 그래요
    var reverify: [String: String]
    var answeredCount: Int
    var totalCount: Int

    var isEmpty: Bool { outcomes.isEmpty && reverify.isEmpty }
}

/// 보관함은 하나뿐이다. 두 앱을 동시에 QA하는 일은 없다고 보았다.
enum SessionDraftStore {
    static let key = "sessionDraft"

    static func load(_ defaults: UserDefaults = .shared) -> SessionDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SessionDraft.self, from: data)
    }

    static func save(_ draft: SessionDraft, to defaults: UserDefaults = .shared) {
        // 아무것도 답하지 않은 상태는 맡아 둘 것이 없다.
        guard !draft.isEmpty else {
            clear(defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(_ defaults: UserDefaults = .shared) {
        defaults.removeObject(forKey: key)
    }
}
