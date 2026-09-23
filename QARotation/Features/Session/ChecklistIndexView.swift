import SwiftUI

/// 무엇이 남았는지 한눈에 보고 골라서 건너뛰는 목차.
/// 여기서는 답하지 않는다. 제목만 훑고 고르면 그 항목으로 간다.
struct ChecklistIndexView: View {
    @Bindable var model: SessionViewModel
    @Binding var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var onlyUnanswered = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.sections) { section in
                    let rows = visibleRows(in: section)
                    if !rows.isEmpty {
                        Section {
                            ForEach(rows, id: \.self) { itemIndex in
                                row(itemIndex)
                            }
                        } header: {
                            HStack {
                                Text(section.category.label)
                                Spacer()
                                Text("\(answered(in: section))/\(section.itemIDs.count)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("테스트 항목 \(model.answeredCount)/\(model.drafts.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(onlyUnanswered ? "전체 보기" : "남은 것만") {
                        withAnimation { onlyUnanswered.toggle() }
                    }
                }
            }
            .overlay {
                if onlyUnanswered, model.unansweredCount == 0 {
                    ContentUnavailableView(
                        "다 봤어요",
                        systemImage: "checkmark.circle",
                        description: Text("완료를 누르면 기록으로 남습니다.")
                    )
                }
            }
        }
    }

    private func visibleRows(in section: SessionViewModel.CategorySection) -> [Int] {
        section.itemIDs.compactMap { id in
            guard let itemIndex = model.index(of: id) else { return nil }
            if onlyUnanswered, model.drafts[itemIndex].outcome != nil { return nil }
            return itemIndex
        }
    }

    private func answered(in section: SessionViewModel.CategorySection) -> Int {
        section.itemIDs.filter { id in
            guard let itemIndex = model.index(of: id) else { return false }
            return model.drafts[itemIndex].outcome != nil
        }.count
    }

    private func row(_ itemIndex: Int) -> some View {
        let draft = model.drafts[itemIndex]
        return Button {
            index = itemIndex
            dismiss()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                mark(draft.outcome)
                VStack(alignment: .leading, spacing: 2) {
                    Text(draft.title)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if itemIndex == index {
                        Text("지금 보는 항목").font(.caption).foregroundStyle(.tint)
                    }
                }
                Spacer(minLength: 0)
                if let badge = draft.verification.badge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.15), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(draft.title), \(draft.outcome?.label ?? "아직 안 함")")
        .accessibilityHint("이 항목으로 갑니다")
    }

    @ViewBuilder
    private func mark(_ outcome: Outcome?) -> some View {
        switch outcome {
        case .pass: Image(systemName: Outcome.pass.symbol).foregroundStyle(.green)
        case .fail: Image(systemName: Outcome.fail.symbol).foregroundStyle(.red)
        case .na: Image(systemName: Outcome.na.symbol).foregroundStyle(.secondary)
        case nil: Image(systemName: "circle").foregroundStyle(.quaternary)
        }
    }
}
