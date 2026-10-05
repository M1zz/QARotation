import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct AppsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ImportController.self) private var importer
    @Query private var apps: [TrackedApp]
    @State private var search = ""
    @State private var showingAdd = false
    @State private var pendingDelete: TrackedApp?
    @State private var importingResults = false
    /// 아이패드에서는 오른쪽에 펼쳐 둘 앱. 아이폰에서는 밀어 넣은 화면이 된다.
    @State private var selectedID: TrackedApp.ID?

    /// 오래 안 본 순서: 한 번도 안 한 앱 → 마지막 QA 가 오래된 앱.
    static func byStaleness(_ apps: [TrackedApp]) -> [TrackedApp] {
        apps.sorted { a, b in
            switch (a.lastQADate, b.lastQADate) {
            case (nil, nil): a.name.localizedStandardCompare(b.name) == .orderedAscending
            case (nil, _): true
            case (_, nil): false
            case let (l?, r?): l == r ? a.name.localizedStandardCompare(b.name) == .orderedAscending : l < r
            }
        }
    }

    private var filtered: [TrackedApp] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                let active = Self.byStaleness(filtered.filter { !$0.isArchived })
                let archived = filtered.filter(\.isArchived).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                // 로테이션에 있는데 이 앱만의 항목이 없으면, 추천돼도 기본 항목만 보고 끝난다. 먼저 채우라고 맨 위에 모은다.
                let empty = active.filter(\.hasNoOwnChecklist)
                let ready = active.filter { !$0.hasNoOwnChecklist }

                if !empty.isEmpty {
                    Section {
                        ForEach(empty) { app in
                            NavigationLink(value: app.id) { AppRow(app: app) }
                                .swipeActions { deleteButton(app) }
                        }
                    } header: {
                        Label("체크리스트가 비어 있는 앱 \(empty.count)개", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("이 앱만의 체크 항목이 없어 QA를 열어도 기본 항목만 나와요. 앱 화면에서 항목을 더하거나, 지금 QA하지 않을 앱이면 보관하세요.")
                    }
                }

                Section {
                    ForEach(ready) { app in
                        NavigationLink(value: app.id) { AppRow(app: app) }
                            .swipeActions { deleteButton(app) }
                    }
                } header: {
                    Text(empty.isEmpty ? "로테이션 \(active.count)개" : "로테이션 \(active.count)개 중 체크리스트가 있는 \(ready.count)개")
                }

                if !archived.isEmpty {
                    Section("보관됨 \(archived.count)개") {
                        ForEach(archived) { app in
                            NavigationLink(value: app.id) { AppRow(app: app) }
                                .swipeActions { deleteButton(app) }
                        }
                    }
                }
            }
            .navigationTitle("앱")
            .searchable(text: $search, prompt: "앱 이름 또는 번들 ID")
            .overlay {
                if apps.isEmpty {
                    ContentUnavailableView("앱이 없어요", systemImage: "square.grid.2x2", description: Text("오른쪽 위 버튼으로 App Store에서 가져오세요."))
                }
            }
            .refreshable { await importer.run(context: context) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await importer.run(context: context) }
                    } label: {
                        if importer.isRunning {
                            ProgressView()
                        } else {
                            Label("App Store에서 새로고침", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(importer.isRunning)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importingResults = true } label: {
                        Label("Claude 결과지 가져오기", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityHint("맥에서 Claude가 만든 QA 결과지와 스크린샷을 고릅니다")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Label("직접 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AppEditView(app: nil) }
            // 결과지와 함께 스크린샷 PNG 를 골라도 된다. 결과지에 적힌 이름으로 맞춰 붙인다.
            .fileImporter(isPresented: $importingResults, allowedContentTypes: [.json, .png], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    importer.importClaudeResults(urls, context: context)
                }
            }
            .confirmationDialog(
                "\(pendingDelete?.name ?? "")을(를) 삭제할까요?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { app in
                Button("QA 기록까지 삭제", role: .destructive) {
                    if selectedID == app.id { selectedID = nil }
                    context.delete(app)
                    try? context.save()
                    PickChangeCoordinator.pickDidChange(context: context)
                }
            } message: { _ in
                Text("QA 기록과 이슈도 함께 지워집니다. 로테이션에서만 빼려면 앱 화면에서 보관을 켜세요.")
            }
        } detail: {
            // 상세 안에서 이슈·기록으로 더 들어가므로 스택을 둔다. 다른 앱을 고르면 쌓인 화면을 비운다.
            NavigationStack {
                if let app = apps.first(where: { $0.id == selectedID }) {
                    AppDetailView(app: app)
                } else {
                    ContentUnavailableView("앱을 고르세요", systemImage: "square.grid.2x2")
                }
            }
            .id(selectedID)
        }
    }
}

struct AppRow: View {
    let app: TrackedApp
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var iconSize: CGFloat = 44

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            AppIconView(app: app, size: iconSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.body.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                if showsEmptyChecklist {
                    Label("체크리스트 없음", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 6) {
                if !app.openIssues.isEmpty {
                    Label("\(app.openIssues.count)", systemImage: "ladybug.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
                LastQABadge(lastQADate: app.lastQADate)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !app.currentVersion.isEmpty { parts.append("v\(app.currentVersion)") }
        if !app.platforms.isEmpty { parts.append(app.platforms.map(\.label).joined(separator: ", ")) }
        if app.tier != .normal { parts.append("우선순위 \(app.tier.label)") }
        return parts.joined(separator: " · ")
    }

    /// 체크리스트가 빈 앱은 이름 아래에 주황 표시를 붙인다(보관한 앱은 QA하지 않으니 빼고).
    private var showsEmptyChecklist: Bool { app.hasNoOwnChecklist && !app.isArchived }

    private var accessibilityText: String {
        var parts = [app.name, LastQAText.sentence(app.lastQADate)]
        if !app.openIssues.isEmpty { parts.append("열린 이슈 \(app.openIssues.count)개") }
        if app.tier != .normal { parts.append("우선순위 \(app.tier.label)") }
        if showsEmptyChecklist { parts.append("체크리스트 없음") }
        return parts.joined(separator: ", ")
    }
}

private extension AppsListView {
    func deleteButton(_ app: TrackedApp) -> some View {
        Button("삭제", systemImage: "trash") { pendingDelete = app }
            .tint(.red)
    }
}
