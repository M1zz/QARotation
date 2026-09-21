import SwiftUI

/// 마지막 QA 이후 며칠이 지났는지. 21일을 넘기면 빨강.
struct LastQABadge: View {
    let lastQADate: Date?
    var now: Date = .now

    private var days: Int? {
        lastQADate.map { Rotation.daysSince($0, now: now) }
    }

    private var text: String {
        guard let days else { return "미검사" }
        return days == 0 ? "오늘" : "\(days)일"
    }

    private var tint: Color {
        guard let days else { return .blue }
        if days > Rotation.overdueThresholdDays { return .red }
        if days > 14 { return .orange }
        return .green
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

enum LastQAText {
    static func sentence(_ date: Date?, now: Date = .now) -> String {
        guard let date else { return "아직 QA한 적 없어요" }
        let days = Rotation.daysSince(date, now: now)
        return days == 0 ? "오늘 QA했어요" : "마지막 QA \(days)일 전"
    }
}
