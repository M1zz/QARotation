import PhotosUI
import SwiftUI

struct ChecklistRow: View {
    @Binding var draft: DraftResult
    let onSelect: (Outcome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(draft.title)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if draft.isAppSpecific {
                    Text("이 앱")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .accessibilityLabel("이 앱 전용 항목")
                }
            }

            if !draft.steps.isEmpty {
                Text(draft.steps)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("확인하는 방법. \(draft.steps)")
            }

            OutcomeButtons(itemTitle: draft.title, selection: draft.outcome, onSelect: onSelect)

            if draft.outcome == .fail {
                TextField("무엇이 문제였나요? (선택)", text: $draft.note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                ScreenshotPicker(data: $draft.screenshot)
            }
        }
        .padding(.vertical, 6)
        .animation(.default, value: draft.outcome)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onSelect(.pass) } label: { Label("통과", systemImage: Outcome.pass.symbol) }
                .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { onSelect(.fail) } label: { Label("실패", systemImage: Outcome.fail.symbol) }
                .tint(.red)
            Button { onSelect(.na) } label: { Label("해당 없음", systemImage: Outcome.na.symbol) }
                .tint(.gray)
        }
    }
}

struct ScreenshotPicker: View {
    @Binding var data: Data?
    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 12) {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("첨부한 스크린샷")
                Button("빼기", role: .destructive) {
                    self.data = nil
                    selection = nil
                }
                .buttonStyle(.borderless)
            }
            let loading = isLoading
            let hasData = data != nil
            PhotosPicker(selection: $selection, matching: .images) {
                if loading {
                    ProgressView()
                } else {
                    Label(hasData ? "바꾸기" : "스크린샷 첨부", systemImage: "photo.badge.plus")
                }
            }
            .buttonStyle(.borderless)
        }
        .task(id: selection) {
            guard let selection else { return }
            isLoading = true
            data = try? await selection.loadTransferable(type: Data.self)
            isLoading = false
        }
    }
}

struct ReverifyRow: View {
    let issue: Issue
    let decision: ReverifyDecision?
    let onSelect: (ReverifyDecision) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title).font(.body.weight(.medium))
                if !issue.note.isEmpty {
                    Text(issue.note).font(.callout).foregroundStyle(.secondary)
                }
                Text("\(issue.createdAt, format: .dateTime.month().day())에 발견")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                choice(.fixed, title: "고쳐졌어요", symbol: "checkmark.circle.fill", tint: .green)
                choice(.stillFailing, title: "아직 그래요", symbol: "exclamationmark.circle.fill", tint: .red)
            }
        }
        .padding(.vertical, 6)
    }

    private func choice(_ value: ReverifyDecision, title: String, symbol: String, tint: Color) -> some View {
        Button {
            onSelect(value)
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(OutcomeButtonStyle(tint: tint, isSelected: decision == value))
        .accessibilityLabel("\(issue.title), \(title)")
        .accessibilityAddTraits(decision == value ? .isSelected : [])
    }
}
