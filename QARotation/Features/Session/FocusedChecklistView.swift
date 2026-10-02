import SwiftUI

/// 항목마다 카드 한 장으로 크게 펼쳐 놓고, 옆으로 넘기며 차례대로 답하는 화면.
/// 목록으로 보면 단계가 작은 글씨로 묻혀서, 손에 기기를 든 채 따라 하기 어렵다.
struct FocusedChecklistView: View {
    @Bindable var model: SessionViewModel
    @Binding var index: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 가로로 넘기는 카드 줄에서 지금 가운데 있는 카드. `index` 와 서로 맞춘다.
    @State private var position: Int?
    /// 켜면 통과한 카드는 줄에서 빠져, 넘길 때 남은 것·실패한 것만 지나간다. 지금 보는 카드는 빼지 않는다.
    @AppStorage(SettingsKey.skipPassedCards, store: .shared) private var skipPassed = false

    var body: some View {
        VStack(spacing: 0) {
            whereBar
            cards
            answerBar
        }
        .background(Color(.systemGroupedBackground))
    }

    /// 지금 앱의 어느 구역에서 몇 번째를 보고 있는지. 아래 막대는 구역마다 한 칸이고 얼마나 했는지 차오른다.
    @ViewBuilder
    private var whereBar: some View {
        let areas = model.areas
        if let current = areas.first(where: { $0.indices.contains(index) }) {
            let position = index - current.indices.lowerBound + 1
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(current.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(position) / \(current.indices.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                    Spacer(minLength: 8)
                    Text("전체 \(index + 1) / \(model.drafts.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("지금 \(current.name), 이 구역 \(current.indices.count)개 중 \(position)번째, 전체 \(model.drafts.count)개 중 \(index + 1)번째")

                areaStrip(areas, current: current)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .readableColumn()
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }

    /// 구역마다 항목 수만큼 폭을 나눠 가진 칸. 누르면 그 구역의 아직 안 한 첫 항목으로 간다.
    private func areaStrip(_ areas: [SessionViewModel.Area], current: SessionViewModel.Area) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let usable = max(geo.size.width - spacing * CGFloat(areas.count - 1), 0)
            HStack(spacing: spacing) {
                ForEach(areas) { area in
                    let isCurrent = area.id == current.id
                    let done = Double(model.answeredCount(in: area)) / Double(area.indices.count)
                    Button {
                        let target = area.indices.first { model.drafts[$0].outcome == nil } ?? area.indices.lowerBound
                        withAnimation { index = target }
                    } label: {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .overlay(alignment: .leading) {
                                GeometryReader { bar in
                                    Capsule()
                                        .fill(Color.accentColor.opacity(isCurrent ? 1 : 0.55))
                                        .frame(width: bar.size.width * done)
                                }
                            }
                            .overlay {
                                if isCurrent { Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5) }
                            }
                            .frame(height: isCurrent ? 10 : 6)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(usable * CGFloat(area.indices.count) / CGFloat(max(model.drafts.count, 1)), 4))
                    .accessibilityLabel("\(area.name), \(area.indices.count)개 중 \(model.answeredCount(in: area))개 함")
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
        }
        .frame(height: 16)
    }

    private var draft: DraftResult { model.drafts[index] }

    /// 카드 줄에 놓을 항목. 건너뛰기를 켜면 통과한 것을 뺀다.
    private var shownIndices: [Int] {
        guard skipPassed else { return Array(model.drafts.indices) }
        return model.drafts.indices.filter { $0 == index || model.drafts[$0].outcome != .pass }
    }

    /// 한 장만 덩그러니 있으면 답답해서, 앞뒤 카드가 양옆에 걸쳐 보이게 늘어놓고 밀어서 넘긴다.
    private var cards: some View {
        GeometryReader { geo in
            // 아이폰에서는 이웃 카드가 손톱만큼, 아이패드에서는 넉넉하게 보인다.
            let cardWidth = max(min(geo.size.width - 88, 560), 0)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(shownIndices, id: \.self) { i in
                        card(i)
                            .frame(width: cardWidth, height: geo.size.height)
                            // 옆 카드는 눌러서 그 카드로 간다. 그 안의 칸과 버튼은 가운데로 와야 쓴다.
                            .overlay {
                                if i != index {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { withAnimation { index = i } }
                                        .accessibilityHidden(true)
                                }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, (geo.size.width - cardWidth) / 2)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .onAppear { position = index }
        .onChange(of: position) { _, new in
            if let new, new != index { index = new }
        }
        .onChange(of: index) { _, new in
            if position != new { withAnimation { position = new } }
        }
    }

    private func card(_ i: Int) -> some View {
        let draft = model.drafts[i]
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(draft, at: i)
                title(draft)
                CarriedCard(draft: draft)
                steps(draft)
                if draft.outcome == .fail { failDetail(i) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            shape.fill(Color(.secondarySystemGroupedBackground))
            if let outcome = draft.outcome { shape.fill(outcome.tint.opacity(0.14)) }
        }
        .clipShape(shape)
        // 답한 카드는 테두리로 한눈에 갈린다. 옆에 흐리게 걸친 카드에서도 보이게 굵게.
        .overlay {
            if let outcome = draft.outcome { shape.strokeBorder(outcome.tint, lineWidth: 3) }
        }
    }

    private func header(_ draft: DraftResult, at i: Int) -> some View {
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
            // 넘기다가도 어느 카드에 답했는지 보이게 한다.
            if let outcome = draft.outcome {
                Label(outcome.label, systemImage: outcome.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(outcome.tint, in: Capsule())
            }
            Text("\(i + 1) / \(model.drafts.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func title(_ draft: DraftResult) -> some View {
        Text(draft.title)
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func steps(_ draft: DraftResult) -> some View {
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
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func failDetail(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("무엇이 문제였나요?").font(.subheadline.weight(.semibold))
            TextField("메모 (선택)", text: $model.drafts[i].note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            ScreenshotPicker(data: $model.drafts[i].screenshot)
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
                answerButton(.pass, tint: .green, key: "1")
                answerButton(.fail, tint: .red, key: "2")
                answerButton(.na, tint: .gray, key: "3")
            }

            HStack {
                Button {
                    if let previous { withAnimation { index = previous } }
                } label: {
                    Label("이전", systemImage: "chevron.left")
                }
                .disabled(previous == nil)
                .keyboardShortcut("[", modifiers: .command)

                Spacer()

                Toggle("통과 건너뛰기", isOn: $skipPassed.animation())
                    .toggleStyle(CapsuleToggleStyle())
                    .accessibilityHint("켜면 통과한 항목은 넘길 때 지나칩니다")

                Spacer()

                Button {
                    if let next { withAnimation { index = next } }
                } label: {
                    Label("다음", systemImage: "chevron.right")
                }
                .disabled(next == nil)
                .keyboardShortcut("]", modifiers: .command)
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .readableColumn()
        .background(.bar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// 아이패드에 키보드를 붙이면 ⌘1·⌘2·⌘3 으로 답한다. 실패 메모를 적는 중에도 글자가 먹히지 않게 ⌘ 를 붙였다.
    private func answerButton(_ outcome: Outcome, tint: Color, key: KeyEquivalent) -> some View {
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
        .keyboardShortcut(key, modifiers: .command)
        .accessibilityLabel("\(draft.title), \(outcome.label)")
        .accessibilityAddTraits(draft.outcome == outcome ? .isSelected : [])
    }

    /// 이전·다음도 카드 줄을 따른다. 건너뛰기를 켜면 통과한 항목을 지나친다.
    private var previous: Int? { shownIndices.last { $0 < index } }
    private var next: Int? { shownIndices.first { $0 > index } }

    private func goToNextUnanswered() {
        guard let next = model.nextUnanswered(after: index) else { return }
        withAnimation { index = next }
    }
}

/// 켜졌는지 한눈에 보이는 작은 캡슐 토글. 켜면 색이 채워지고 체크가 붙는다.
private struct CapsuleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Label {
                configuration.label
            } icon: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(configuration.isOn ? Color.white : Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isOn ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
