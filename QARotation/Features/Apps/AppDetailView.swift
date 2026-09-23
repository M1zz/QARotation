import SwiftData
import SwiftUI

struct AppDetailView: View {
    @Bindable var app: TrackedApp
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var newItemTitle = ""
    @State private var showingEdit = false
    @ScaledMetric private var iconSize: CGFloat = 72

    var body: some View {
        List {
            header

            Section {
                Picker("우선순위", selection: $app.tier) {
                    ForEach(Tier.allCases) { Text($0.label).tag($0) }
                }
                Toggle("로테이션에서 빼기(보관)", isOn: $app.isArchived)
                TextField("테스트 중인 버전 (예: 2.2.4)", text: $app.testingVersion)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(save)
                if app.hasNewerStoreVersion {
                    Button("스토어 최신 v\(app.currentVersion)으로 바꾸기") {
                        app.testingVersion = app.currentVersion
                        save()
                    }
                }
                TextField("URL 스킴 (예: myapp)", text: $app.urlScheme)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("메모", text: $app.notes, axis: .vertical)
            } header: {
                Text("설정")
            } footer: {
                Text("테스트 중인 버전은 QA 기록에 함께 남습니다. 비워 두면 스토어의 현재 버전을 씁니다.\nURL 스킴이 있으면 QA 중 \"앱 열기\"가 앱을 바로 열고, 없으면 App Store 페이지를 엽니다.")
            }

            extraItemsSection
            issuesSection
            historySection
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("편집") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) { AppEditView(app: app) }
        .onChange(of: app.tierRaw) { save() }
        .onChange(of: app.isArchived) { save() }
    }

    private var header: some View {
        Section {
            VStack(spacing: 12) {
                AppIconView(app: app, size: iconSize)
                Text(app.name).font(.title2.bold()).multilineTextAlignment(.center)
                Text(detailLine).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(LastQAText.sentence(app.lastQADate)).font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            Button {
                router.startSession(app.id)
            } label: {
                WideButtonLabel(title: "QA 시작", systemImage: "play.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(app.isArchived)

            if let url = app.launchURL ?? app.storeURL {
                Button {
                    openURL(url)
                } label: {
                    WideButtonLabel(
                        title: app.launchURL == nil ? "App Store에서 보기" : "앱 열기",
                        systemImage: "arrow.up.forward.app",
                        minHeight: 36
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .listRowSeparator(.hidden)
    }

    private var detailLine: String {
        var parts: [String] = []
        if !app.versionUnderTest.isEmpty { parts.append("테스트 중 v\(app.versionUnderTest)") }
        if app.hasNewerStoreVersion { parts.append("스토어 v\(app.currentVersion)") }
        if !app.platforms.isEmpty { parts.append(app.platforms.map(\.label).joined(separator: ", ")) }
        if !app.bundleID.isEmpty { parts.append(app.bundleID) }
        return parts.joined(separator: " · ")
    }

    private var extraItemsSection: some View {
        Section {
            ForEach(app.sortedExtraItems) { item in
                Text(item.title)
            }
            .onDelete { offsets in
                let items = app.sortedExtraItems
                for index in offsets { context.delete(items[index]) }
                save()
            }
            HStack {
                TextField("항목 추가", text: $newItemTitle)
                    .onSubmit(addExtraItem)
                Button("추가", action: addExtraItem)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let missing = AppChecklistSeeder.missingCount(for: app)
            if missing > 0 {
                Button("빠진 추천 항목 \(missing)개 다시 넣기") {
                    AppChecklistSeeder.restoreMissing(for: app, in: context)
                }
            }
        } header: {
            Text("이 앱만의 체크 항목")
        } footer: {
            Text("기본 체크리스트 뒤에 붙습니다.")
        }
    }

    private func addExtraItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let order = (app.sortedExtraItems.last?.order ?? -1) + 1
        let item = ChecklistItem(title: title, category: .custom, order: order, isDefault: false)
        context.insert(item)
        item.app = app
        newItemTitle = ""
        save()
    }

    @ViewBuilder
    private var issuesSection: some View {
        let issues = (app.issues ?? []).sorted {
            ($0.status == .open ? 0 : 1, $1.createdAt) < ($1.status == .open ? 0 : 1, $0.createdAt)
        }
        if !issues.isEmpty {
            Section("이슈") {
                ForEach(issues) { issue in
                    NavigationLink {
                        IssueDetailView(issue: issue)
                    } label: {
                        IssueRow(issue: issue, showsApp: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        let sessions = app.sortedSessions
        if sessions.isEmpty {
            Section("QA 기록") {
                Text("아직 기록이 없어요").foregroundStyle(.secondary)
            }
        } else {
            // 어느 버전을 몇 번 봤는지 한눈에 들어오도록 버전별로 묶는다. 최근에 본 버전이 위에 온다.
            ForEach(VersionHistory.groups(of: sessions)) { group in
                Section("\(group.title) · \(group.sessions.count)회") {
                    ForEach(group.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                    .onDelete { offsets in
                        delete(offsets.map { group.sessions[$0] })
                    }
                }
            }
        }
    }

    private func delete(_ sessions: [QASession]) {
        let removed = Set(sessions.map(\.id))
        for session in sessions { context.delete(session) }
        app.lastQADate = app.sortedSessions.first { !removed.contains($0.id) }?.date
        save()
    }

    private func save() {
        try? context.save()
        PickChangeCoordinator.pickDidChange(context: context)
    }
}

struct SessionRow: View {
    let session: QASession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date, format: .dateTime.year().month().day().hour().minute())
                .font(.body.weight(.medium))
            HStack(spacing: 10) {
                Label("\(session.count(of: .pass))", systemImage: Outcome.pass.symbol).foregroundStyle(.green)
                Label("\(session.count(of: .fail))", systemImage: Outcome.fail.symbol).foregroundStyle(.red)
                Label("\(session.count(of: .na))", systemImage: Outcome.na.symbol).foregroundStyle(.secondary)
                if !session.appVersion.isEmpty {
                    Text("v\(session.appVersion)").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(session.date.formatted(date: .long, time: .shortened)), 통과 \(session.count(of: .pass))개, 실패 \(session.count(of: .fail))개, 해당 없음 \(session.count(of: .na))개"
        )
    }
}
