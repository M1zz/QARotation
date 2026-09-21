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
