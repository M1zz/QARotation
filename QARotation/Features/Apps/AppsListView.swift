import SwiftData
import SwiftUI

struct AppsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ImportController.self) private var importer
    @Query private var apps: [TrackedApp]
    @State private var search = ""
    @State private var showingAdd = false
    @State private var pendingDelete: TrackedApp?

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
        NavigationStack {
            List {
                let active = Self.byStaleness(filtered.filter { !$0.isArchived })
                let archived = filtered.filter(\.isArchived).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

                Section {
                    ForEach(active) { app in
                        NavigationLink(value: app) { AppRow(app: app) }
                            .swipeActions { deleteButton(app) }
                    }
                } header: {
                    Text("로테이션 \(active.count)개")
                }

                if !archived.isEmpty {
                    Section("보관됨 \(archived.count)개") {
                        ForEach(archived) { app in
                            NavigationLink(value: app) { AppRow(app: app) }
                                .swipeActions { deleteButton(app) }
                        }
                    }
                }
            }
            .navigationTitle("앱")
            .navigationDestination(for: TrackedApp.self) { AppDetailView(app: $0) }
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
                    Button { showingAdd = true } label: {
                        Label("직접 추가", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AppEditView(app: nil) }
            .confirmationDialog(
                "\(pendingDelete?.name ?? "")을(를) 삭제할까요?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { app in
                Button("QA 기록까지 삭제", role: .destructive) {
                    context.delete(app)
                    try? context.save()
                    PickChangeCoordinator.pickDidChange(context: context)
                }
            } message: { _ in
                Text("QA 기록과 이슈도 함께 지워집니다. 로테이션에서만 빼려면 앱 화면에서 보관을 켜세요.")
            }
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

    private var accessibilityText: String {
        var parts = [app.name, LastQAText.sentence(app.lastQADate)]
        if !app.openIssues.isEmpty { parts.append("열린 이슈 \(app.openIssues.count)개") }
        if app.tier != .normal { parts.append("우선순위 \(app.tier.label)") }
        return parts.joined(separator: ", ")
    }
}

private extension AppsListView {
    func deleteButton(_ app: TrackedApp) -> some View {
        Button("삭제", systemImage: "trash") { pendingDelete = app }
            .tint(.red)
    }
}
