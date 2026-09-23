import Foundation

/// 로테이션 우선순위 등급. 점수 = 지난 QA 이후 일수 × 등급 가중치.
enum Tier: String, CaseIterable, Codable, Sendable, Identifiable {
    case high, normal, low

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: "높음"
        case .normal: "보통"
        case .low: "낮음"
        }
    }
}

enum ChecklistCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case stability, monetization, appearance, accessibility, platform, store, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stability: "안정성"
        case .monetization: "결제"
        case .appearance: "화면"
        case .accessibility: "접근성"
        case .platform: "플랫폼"
        case .store: "스토어"
        case .custom: "기타"
        }
    }

    var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }
}

/// 이 항목을 무엇으로 확인할 수 있는가. 나중에 코드 테스트를 짜 달라고 할 때 골라 내는 기준이다.
enum Verification: String, CaseIterable, Codable, Sendable, Identifiable {
    /// 사람이 눈과 손으로만 확인할 수 있다(카메라·센서·위젯 그림·실제 알림·미감).
    case manual
    /// 화면 없이 로직과 저장만으로 확인할 수 있다(계산·파싱·정렬·재실행 후 복원).
    case unit
    /// 화면을 띄워 눌러 보면 확인할 수 있다(XCUITest).
    case ui

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "손으로"
        case .unit: "유닛 테스트"
        case .ui: "UI 테스트"
        }
    }

    /// 목록에 붙이는 짧은 표시. 손으로 하는 항목에는 아무것도 붙이지 않는다.
    var badge: String? {
        switch self {
        case .manual: nil
        case .unit: "유닛"
        case .ui: "UI"
        }
    }

    var isAutomatable: Bool { self != .manual }
}

enum Outcome: String, CaseIterable, Codable, Sendable {
    case pass, fail, na

    var label: String {
        switch self {
        case .pass: "통과"
        case .fail: "실패"
        case .na: "해당 없음"
        }
    }

    var symbol: String {
        switch self {
        case .pass: "checkmark.circle.fill"
        case .fail: "xmark.circle.fill"
        case .na: "minus.circle.fill"
        }
    }
}

enum IssueStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case open, fixed, wontFix

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: "열림"
        case .fixed: "고침"
        case .wontFix: "안 고침"
        }
    }
}

enum Platform: String, CaseIterable, Codable, Sendable {
    case iPhone, iPad, mac, watch, tv, vision

    var label: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .watch: "Watch"
        case .tv: "TV"
        case .vision: "Vision"
        }
    }
}
