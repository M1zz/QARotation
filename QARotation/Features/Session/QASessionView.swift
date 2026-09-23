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
    @Environment(\.openURL) private var openURL
    /// 한 항목씩 크게 보며 따라 하는 모드. 모든 앱이 이 화면으로 열린다.
    @State private var focusMode = true
    @State private var focusIndex = 0
    @State private var pickingVersion = false
    @State private var showingIndex = false

    var body: some View {
        NavigationStack {
            Group {
                if focusMode {
                    focusBody
                } else {
                    listBody
                }
            }
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
                ToolbarItem(placement: .primaryAction) {
                    if focusMode {
                        Button {
                            showingIndex = true
                        } label: {
                            Label("테스트 항목 보기", systemImage: "list.bullet.indent")
                        }
                    } else {
                        Button {
                            withAnimation { focusMode = true }
                        } label: {
                            Label("한 장씩 보기", systemImage: "rectangle.portrait")
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
            .sheet(isPresented: $showingIndex) {
                ChecklistIndexView(model: model, index: $focusIndex)
            }
            .task {
                // 이어서 하는 경우 아직 답하지 않은 첫 항목에서 시작한다.
                focusIndex = model.drafts.firstIndex { $0.outcome == nil } ?? 0
            }
        }
    }

    /// 한 장씩 보기: 위에 앱과 타이머, 가운데 항목 하나, 아래 답 버튼.
    private var focusBody: some View {
        VStack(spacing: 0) {
            focusTopBar
            Divider()
            FocusedChecklistView(model: model, index: $focusIndex)
            Divider()
            focusBottomBar
        }
    }

    private var focusTopBar: some View {
        HStack(spacing: 12) {
            AppIconView(app: model.app, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                SessionTimerView(startedAt: model.meta.startedAt, limitSeconds: model.timerSeconds)
                Button {
                    pickingVersion = true
                } label: {
                    Label(
                        model.meta.appVersion.isEmpty ? "버전 고르기" : "테스트 중 v\(model.meta.appVersion)",
                        systemImage: "chevron.down"
                    )
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let url = model.app.launchURL ?? model.app.storeURL {
                Button {
                    openApp(primary: url)
                } label: {
                    Label("앱 열기", systemImage: "arrow.up.forward.app")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityLabel(model.app.launchURL == nil ? "App Store에서 열기" : "앱 열기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .sheet(isPresented: $pickingVersion) {
            VersionPicker(app: model.app, version: $model.meta.appVersion)
        }
    }

    private var focusBottomBar: some View {
        HStack(spacing: 12) {
            ProgressView(value: Double(model.answeredCount), total: Double(max(model.drafts.count, 1)))
                .accessibilityLabel("진행")
                .accessibilityValue("\(model.drafts.count)개 중 \(model.answeredCount)개")
            Text("\(model.answeredCount)/\(model.drafts.count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            finishButton
                .frame(maxWidth: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// URL 스킴으로 못 열면 App Store 로 보낸다(세션 머리말과 같은 방식).
    private func openApp(primary: URL) {
        let fallback = model.app.storeURL
        let open = openURL
        open(primary) { accepted in
            if !accepted, let fallback, fallback != primary { open(fallback) }
        }
    }

    private var listBody: some View {
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
