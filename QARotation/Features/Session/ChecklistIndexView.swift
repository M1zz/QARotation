import SwiftUI

/// 무엇이 남았는지 한눈에 보고 골라서 건너뛰는 목차.
/// 여기서는 답하지 않는다. 제목만 훑고 고르면 그 항목으로 간다.
struct ChecklistIndexView: View {
    @Bindable var model: SessionViewModel
    @Binding var index: Int
    @Environment(\.dismiss) private var dismiss
    @State private var filter: Filter = .all

    /// 목차에서 무엇만 볼 것인가.
    enum Filter: String, CaseIterable, Identifiable {
        case all, unanswered, automatable
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "전체"
            case .unanswered: "남은 것만"
            case .automatable: "코드로 되는 것"
            }
        }
    }

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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.bar)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                }
            }
            // 평평한 목록이라야 섹션 이름이 위에 붙은 채로 스크롤된다.
            .listStyle(.plain)
            .safeAreaInset(edge: .top) { summary }
            .navigationTitle("테스트 항목 \(model.answeredCount)/\(model.drafts.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("보기", selection: $filter) {
                            ForEach(Filter.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Label(filter.label, systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
            .overlay {
                if visibleCount == 0 {
                    ContentUnavailableView(
                        filter == .unanswered ? "다 봤어요" : "해당하는 항목이 없어요",
                        systemImage: filter == .unanswered ? "checkmark.circle" : "line.3.horizontal.decrease",
                        description: Text(filter == .unanswered ? "완료를 누르면 기록으로 남습니다." : "보기를 바꿔 보세요.")
                    )
                }
            }
        }
    }

    /// 코드로 할 수 있는 항목이 몇 개인지 위쪽에 적어 둔다. 나중에 테스트로 옮길 거리를 세어 보라고.
    @ViewBuilder
    private var summary: some View {
        let unit = model.drafts.filter { $0.verification == .unit }.count
        let ui = model.drafts.filter { $0.verification == .ui }.count
        if unit + ui > 0 {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text("코드로 되는 것 \(unit + ui)개 · 유닛 \(unit) · UI \(ui)")
                Spacer(minLength: 0)
                if filter != .automatable {
                    Button("모아 보기") { withAnimation { filter = .automatable } }
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var visibleCount: Int {
        model.sections.reduce(0) { $0 + visibleRows(in: $1).count }
    }

    private func visibleRows(in section: SessionViewModel.CategorySection) -> [Int] {
        section.itemIDs.compactMap { id in
            guard let itemIndex = model.index(of: id) else { return nil }
            let draft = model.drafts[itemIndex]
            switch filter {
            case .all: break
            case .unanswered: if draft.outcome != nil { return nil }
            case .automatable: if !draft.verification.isAutomatable { return nil }
            }
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
