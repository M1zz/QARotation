import SwiftUI

/// 항목 하나를 크게 펼쳐 놓고 차례대로 답하는 화면.
/// 목록으로 보면 단계가 작은 글씨로 묻혀서, 손에 기기를 든 채 따라 하기 어렵다.
struct FocusedChecklistView: View {
    @Bindable var model: SessionViewModel
    @Binding var index: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    title
                    steps
                    if draft.outcome == .fail { failDetail }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(draft.id)
            }
            answerBar
        }
    }

    private var draft: DraftResult { model.drafts[index] }

    private var header: some View {
        HStack {
            Text(draft.category.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if draft.isAppSpecific {
                Text("이 앱")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            if let badge = draft.verification.badge {
                Text(badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.15), in: Capsule())
            }
            Spacer()
            Text("\(index + 1) / \(model.drafts.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text(draft.title)
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var steps: some View {
        let broken = StepText.broken(draft.steps)
        if !broken.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(broken.actions.enumerated()), id: \.offset) { order, action in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(order + 1)")
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(width: 26, height: 26)
                            .background(.tint.opacity(0.15), in: Circle())
                        Text(action)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(order + 1)번째, \(action)")
                }

                if let expectation = broken.expectation {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "eye")
                            .frame(width: 26, height: 26)
                            .foregroundStyle(.green)
                        Text(expectation)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("이렇게 되면 통과. \(expectation)")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var failDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("무엇이 문제였나요?").font(.subheadline.weight(.semibold))
            TextField("메모 (선택)", text: $model.drafts[index].note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            ScreenshotPicker(data: $model.drafts[index].screenshot)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var answerBar: some View {
        VStack(spacing: 10) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                answerButton(.pass, tint: .green)
                answerButton(.fail, tint: .red)
                answerButton(.na, tint: .gray)
            }

            HStack {
                Button {
                    move(by: -1)
                } label: {
                    Label("이전", systemImage: "chevron.left")
                }
                .disabled(index == 0)

                Spacer()

                Button {
                    move(by: 1)
                } label: {
                    Label("다음", systemImage: "chevron.right")
                }
                .disabled(index >= model.drafts.count - 1)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func answerButton(_ outcome: Outcome, tint: Color) -> some View {
        Button {
            model.setOutcome(outcome, for: draft.id)
            // 실패는 메모를 적어야 하니 그 자리에 머문다.
            if model.drafts[index].outcome != nil, outcome != .fail { goToNextUnanswered() }
        } label: {
            Label(outcome.label, systemImage: outcome.symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(OutcomeButtonStyle(tint: tint, isSelected: draft.outcome == outcome))
        .accessibilityLabel("\(draft.title), \(outcome.label)")
        .accessibilityAddTraits(draft.outcome == outcome ? .isSelected : [])
    }

    private func move(by step: Int) {
        let next = index + step
        guard model.drafts.indices.contains(next) else { return }
        withAnimation { index = next }
    }

    private func goToNextUnanswered() {
        guard let next = model.nextUnanswered(after: index) else { return }
        withAnimation { index = next }
    }
}
