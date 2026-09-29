import SwiftUI

extension Color {
    /// Claude 가 한 것을 표시하는 색. 흰 글씨를 올려도 읽히도록 조금 어둡게 잡았다.
    static let claude = Color(red: 0.74, green: 0.34, blue: 0.20)
}

/// 미리 채운 항목이 어디서 왔는지. QA 화면에서 Claude 가 한 것을 사람이 한 것과 가려 보여 주려고 쓴다.
enum CarriedOrigin {
    /// Claude 가 맥에서 확인했고 사람이 그대로 두었다.
    case claudeChecked(Outcome, note: String)
    /// Claude 가 확인했지만 사람이 답을 바꿨다.
    case claudeOverridden(Outcome)
    /// Claude 가 확인하지 못했다. 이유가 있으면 함께.
    case claudeUnchecked(reason: String)
    /// 지난번에 손으로 확인한 결과를 이어받았다.
    case hand

    init?(_ draft: DraftResult) {
        if let carried = draft.carriedOutcome {
            if !draft.carriedFromClaude {
                self = .hand
            } else if draft.outcome == carried {
                self = .claudeChecked(carried, note: draft.claudeNote ?? "")
            } else {
                self = .claudeOverridden(carried)
            }
        } else if let reason = draft.claudeNote {
            self = .claudeUnchecked(reason: reason)
        } else {
            return nil
        }
    }

    var isClaudeChecked: Bool {
        if case .claudeChecked = self { true } else { false }
    }
}

/// "Claude가 확인" 같은 짧은 표시. 목록·한 장씩 보기·목차에서 함께 쓴다.
struct ClaudeBadge: View {
    let origin: CarriedOrigin

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if filled {
                    Capsule().fill(tint)
                } else {
                    Capsule().strokeBorder(tint, lineWidth: 1.5)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }

    private var title: String {
        switch origin {
        case .claudeChecked(let outcome, _): String(localized: "Claude가 확인 · \(outcome.label)")
        case .claudeOverridden: String(localized: "Claude 결과를 바꿈")
        case .claudeUnchecked: String(localized: "Claude가 못 봄")
        case .hand: String(localized: "지난번 손으로 확인")
        }
    }

    private var symbol: String {
        switch origin {
        case .claudeChecked, .claudeOverridden, .claudeUnchecked: "sparkles"
        case .hand: "hand.raised.fill"
        }
    }

    private var tint: Color {
        switch origin {
        case .claudeChecked, .claudeOverridden, .claudeUnchecked: .claude
        case .hand: .secondary
        }
    }

    private var filled: Bool { origin.isClaudeChecked }
}

/// 배지 아래에 Claude 가 남긴 근거나 못 본 이유를 붙인 카드.
struct CarriedCard: View {
    let draft: DraftResult

    var body: some View {
        if let origin = CarriedOrigin(draft) {
            VStack(alignment: .leading, spacing: 8) {
                ClaudeBadge(origin: origin)
                if let detail = detail(origin) {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background(origin), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private func detail(_ origin: CarriedOrigin) -> String? {
        switch origin {
        case .claudeChecked(_, let note):
            return note.isEmpty ? String(localized: "맥에서 자동으로 확인했어요.") : note
        case .claudeOverridden(let outcome):
            return String(localized: "Claude가 본 결과(\(outcome.label))를 직접 바꿨어요.")
        case .claudeUnchecked(let reason):
            return reason.isEmpty ? String(localized: "맥에서는 확인할 수 없었어요. 손으로 확인해 주세요.") : reason
        case .hand:
            return nil
        }
    }

    private func background(_ origin: CarriedOrigin) -> Color {
        switch origin {
        case .hand: Color.secondary.opacity(0.1)
        default: Color.claude.opacity(0.12)
        }
    }
}
