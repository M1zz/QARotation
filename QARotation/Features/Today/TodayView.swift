import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Environment(ImportController.self) private var importer
    @Query private var apps: [TrackedApp]
    @Query private var sessions: [QASession]
    @AppStorage(SettingsKey.weightHigh, store: .shared) private var weightHigh = TierWeights.standard.high
    @AppStorage(SettingsKey.weightNormal, store: .shared) private var weightNormal = TierWeights.standard.normal
    @AppStorage(SettingsKey.weightLow, store: .shared) private var weightLow = TierWeights.standard.low
    /// 건너뛰기는 UserDefaults 에만 남으므로, 화면을 다시 그리게 하는 신호.
    @State private var skipTick = 0
    @State private var showingAddApp = false
    @ScaledMetric(relativeTo: .largeTitle) private var scaledIconSize: CGFloat = 112
    /// 큰 글자에서 아이콘까지 커지면 "QA 시작"이 화면 밖으로 밀려난다.
    private var iconSize: CGFloat { min(scaledIconSize, dynamicTypeSize.isAccessibilitySize ? 88 : 128) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var activeApps: [TrackedApp] { apps.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("오늘")
                .sheet(isPresented: $showingAddApp) { AppEditView(app: nil) }
        }
    }

    @ViewBuilder
    private var content: some View {
        let now = Date.now
        let _ = skipTick
        let weights = TierWeights(high: weightHigh, normal: weightNormal, low: weightLow)
        let candidates = activeApps.map(\.rotationCandidate)
        let skipped = SkipStore().skipped(on: now)

        if apps.isEmpty {
            emptyState
        } else if let chosen = Rotation.pick(from: candidates, now: now, weights: weights, skipped: skipped),
                  let app = activeApps.first(where: { $0.id == chosen.id }) {
            ScrollView {
                VStack(spacing: 24) {
                    pickCard(app, now: now, allIDs: Set(candidates.map(\.id)))
                    progressCard(candidates: candidates, now: now)
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        } else {
            ContentUnavailableView(
                "로테이션에 앱이 없어요",
                systemImage: "archivebox",
                description: Text("앱 탭에서 보관을 풀면 다시 추천해요.")
            )
        }
    }

    private func pickCard(_ app: TrackedApp, now: Date, allIDs: Set<UUID>) -> some View {
        VStack(spacing: 16) {
            AppIconView(app: app, size: iconSize)

            Text(app.name)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // 글자가 아주 크면 시작 버튼을 이름 바로 아래로 올려 스크롤 없이 누를 수 있게 한다.
            if dynamicTypeSize.isAccessibilitySize { startButton(app) }

            VStack(spacing: 6) {
                Text(LastQAText.sentence(app.lastQADate, now: now))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("우선순위 \(app.tier.label)")
                    if !app.openIssues.isEmpty {
                        Text("·")
                        Label("이슈 \(app.openIssues.count)개", systemImage: "ladybug")
                            .foregroundStyle(.red)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if !dynamicTypeSize.isAccessibilitySize { startButton(app) }

            Button {
                SkipStore().skip(app.id, now: now, allCandidateIDs: allIDs)
                skipTick += 1
                PickChangeCoordinator.pickDidChange(context: context)
            } label: {
                WideButtonLabel(title: "다른 앱 추천", systemImage: "forward.fill", minHeight: 36)
            }
            .buttonStyle(.bordered)
            .disabled(allIDs.count < 2)
            .accessibilityHint("오늘은 이 앱을 건너뜁니다. QA 기록으로 남지 않아요.")
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func progressCard(candidates: [RotationCandidate], now: Date) -> some View {
        let active = Set(candidates.map(\.id))
        let stamps = sessions.compactMap { s in s.app.map { SessionStamp(appID: $0.id, date: s.date) } }
        let cycle = Rotation.cycleProgress(sessions: stamps, activeAppIDs: active)
        let overdue = Rotation.overdueCount(candidates, now: now)
        let never = Rotation.neverQACount(candidates)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("이번 사이클")
                        .font(.headline)
                    Spacer()
                    Text("\(cycle.done) / \(cycle.total)")
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                ProgressView(value: Double(cycle.done), total: Double(max(cycle.total, 1)))
                if cycle.completedCycles > 0 {
                    Text("지금까지 \(cycle.completedCycles)바퀴를 돌았어요")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("이번 사이클 \(cycle.total)개 중 \(cycle.done)개 완료")

            Divider()

            Button {
                router.selectedTab = .apps
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Label("21일 넘은 앱 \(overdue)개", systemImage: "exclamationmark.clock")
                        .foregroundStyle(overdue > 0 ? .red : .secondary)
                    if never > 0 {
                        Label("아직 QA 안 한 앱 \(never)개", systemImage: "sparkles")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("앱 목록을 엽니다")
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 등록한 앱이 없어요", systemImage: "square.grid.2x2")
        } description: {
            Text("내 App Store 앱을 한 번에 가져오거나 직접 추가하세요.")
        } actions: {
            Button {
                Task { await importer.run(context: context) }
            } label: {
                if importer.isRunning {
                    ProgressView()
                } else {
                    Text("App Store에서 가져오기")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(importer.isRunning)

            Button("직접 추가") { showingAddApp = true }
        }
    }
}

extension View {
    func importAlert(_ importer: ImportController) -> some View {
        modifier(ImportAlertModifier(importer: importer))
    }
}

private struct ImportAlertModifier: ViewModifier {
    @Bindable var importer: ImportController

    func body(content: Content) -> some View {
        content.alert(
            importer.message?.title ?? "",
            isPresented: Binding(get: { importer.message != nil }, set: { if !$0 { importer.message = nil } }),
            presenting: importer.message
        ) { _ in
            Button("확인") {}
        } message: { message in
            Text(message.body)
        }
    }
}

private extension TodayView {
    func startButton(_ app: TrackedApp) -> some View {
        Button {
            router.startSession(app.id)
        } label: {
            WideButtonLabel(title: "QA 시작", systemImage: "play.fill")
                .font(.title3.bold())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("\(app.name)의 QA 체크리스트를 엽니다")
    }
}
