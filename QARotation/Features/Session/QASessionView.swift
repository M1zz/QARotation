import SwiftData
import SwiftUI

struct QASessionView: View {
    let appID: UUID
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: SessionViewModel?
    @State private var notFound = false

    var body: some View {
        Group {
            if let model {
                SessionContentView(model: model)
            } else if notFound {
                NavigationStack {
                    ContentUnavailableView("앱을 찾을 수 없어요", systemImage: "questionmark.app", description: Text("삭제되었을 수 있어요."))
                        .toolbar { Button("닫기") { dismiss() } }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: appID) { load() }
    }

    private func load() {
        let id = appID
        guard let app = try? context.fetch(FetchDescriptor<TrackedApp>(predicate: #Predicate { $0.id == id })).first else {
            notFound = true
            return
        }
        let defaults = (try? context.fetch(FetchDescriptor<ChecklistItem>(predicate: #Predicate { $0.isDefault }))) ?? []
        model = SessionViewModel(
            app: app,
            defaultItems: defaults,
            timerMinutes: AppSettings.timerMinutes(),
            resuming: SessionDraftStore.load()
        )
    }
}

private struct SessionContentView: View {
    @Bindable var model: SessionViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingCancel = false
    @State private var confirmingPartialFinish = false
    @State private var saveError: String?
    @State private var finished = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    SessionHeaderView(model: model)
                }

                if !model.reverifyIssues.isEmpty {
                    Section {
                        ForEach(model.reverifyIssues) { issue in
                            ReverifyRow(issue: issue, decision: model.reverify[issue.id]) { decision in
                                model.setReverify(decision, for: issue)
                            }
                        }
                    } header: {
                        Text("다시 확인할 이슈 \(model.reverifyIssues.count)개")
                    } footer: {
                        Text("고르지 않으면 열린 채로 둡니다.")
                    }
                }

                ForEach(model.sections) { section in
                    Section(section.category.label) {
                        ForEach(section.itemIDs, id: \.self) { id in
                            if let index = model.index(of: id) {
                                ChecklistRow(draft: $model.drafts[index]) { outcome in
                                    model.setOutcome(outcome, for: id)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle(model.app.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        if model.hasProgress {
                            confirmingCancel = true
                        } else {
                            SessionDraftStore.clear()
                            dismiss()
                        }
                    }
                }
            }
            .confirmationDialog("여기까지 한 것을 어떻게 할까요?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("보관하고 닫기") {
                    model.keepDraft()
                    dismiss()
                }
                Button("버리고 닫기", role: .destructive) {
                    SessionDraftStore.clear()
                    dismiss()
                }
                Button("계속 QA하기", role: .cancel) {}
            }
            .confirmationDialog(
                "답하지 않은 항목 \(model.unansweredCount)개는 기록하지 않아요",
                isPresented: $confirmingPartialFinish,
                titleVisibility: .visible
            ) {
                Button("이대로 완료") { finish() }
                Button("나머지 모두 통과로 완료") {
                    model.markRemainingPass()
                    finish()
                }
                Button("계속 QA하기", role: .cancel) {}
            }
            .alert("저장하지 못했어요", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("확인") {}
            } message: {
                Text(saveError ?? "")
            }
            .sensoryFeedback(.success, trigger: finished)
            // 홈으로 나가거나 앱이 꺼져도 여기까지 한 것이 남도록.
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, model.hasProgress { model.keepDraft() }
            }
            .interactiveDismissDisabled(model.hasProgress)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ProgressView(value: Double(model.answeredCount), total: Double(max(model.drafts.count, 1)))
                .accessibilityLabel("진행")
                .accessibilityValue("\(model.drafts.count)개 중 \(model.answeredCount)개")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { passAllButton; finishButton }
                VStack(spacing: 8) { finishButton; passAllButton }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
        // 고정 막대가 화면을 다 덮지 않게 글자 크기에 상한을 둔다(목록 본문은 제한 없음).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var passAllButton: some View {
        if model.unansweredCount > 0 {
            Button {
                model.markRemainingPass()
            } label: {
                Text("나머지 \(model.unansweredCount)개 통과")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var finishButton: some View {
        Button {
            if model.unansweredCount > 0 && model.answeredCount > 0 {
                confirmingPartialFinish = true
            } else {
                finish()
            }
        } label: {
            Text(model.failCount > 0 ? "완료 · 이슈 \(model.failCount)개" : "완료")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.hasProgress)
    }

    private func finish() {
        do {
            try model.finish(in: context)
            finished = true
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
