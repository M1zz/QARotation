import SwiftUI

/// 통과 · 실패 · 해당 없음. 큰 터치 영역, 한 번에 하나. 같은 버튼을 다시 누르면 선택이 풀린다.
struct OutcomeButtons: View {
    let itemTitle: String
    let selection: Outcome?
    let onSelect: (Outcome) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(Outcome.allCases, id: \.self) { outcome in
                Button {
                    onSelect(outcome)
                } label: {
                    Label(outcome.label, systemImage: outcome.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(OutcomeButtonStyle(tint: outcome.tint, isSelected: selection == outcome))
                .accessibilityLabel("\(itemTitle), \(outcome.label)")
                .accessibilityAddTraits(selection == outcome ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension Outcome {
    var tint: Color {
        switch self {
        case .pass: .green
        case .fail: .red
        case .na: .gray
        }
    }
}

struct OutcomeButtonStyle: ButtonStyle {
    let tint: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.white : tint)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint : tint.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 글자 뒤에 작은 기호를 붙이는 꼬리표. "테스트 중 v5.1.4 ⌄"처럼 누를 수 있음을 알린다.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.caption2)
        }
    }
}
