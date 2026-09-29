import SwiftData
import SwiftUI

/// 한 버전의 QA지. 맥에서 자동으로 본 것, 손으로 본 것, 아직 안 본 것을 나눠 보여 주고
/// 남은 것을 이어서 채우게 한다.
struct VersionSheetView: View {
    let app: TrackedApp
    let version: String
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ChecklistItem> { $0.isDefault }) private var defaultItems: [ChecklistItem]

    var body: some View {
        let sheet = VersionSheet.build(
            version: version,
            sessions: app.sortedSessions,
            checklist: SessionRecorder.drafts(defaultItems: defaultItems, app: app)
        )
        List {
            Section {
                summary(sheet)
                continueButton(sheet)
            }
            rowsSection(
                sheet.automatic,
                title: "자동 · 맥에서 확인",
                systemImage: "sparkles",
                footer: "맥에서 Claude가 시뮬레이터와 테스트로 확인한 항목이에요. 사람이 이어받아 그대로 둔 것도 여기에 들어요."
            )
            rowsSection(
                sheet.manual,
                title: "수동 · 손으로 확인",
                systemImage: "hand.raised",
                footer: "기기에서 직접 확인한 항목이에요."
            )
            rowsSection(
                sheet.pending,
                title: "아직 안 본 항목",
                systemImage: "circle.dashed",
                footer: "Claude가 맥에서 못 본 이유가 있으면 함께 적어 두었어요."
            )
        }
        .navigationTitle(sheet.version.isEmpty ? String(localized: "버전 모름 QA지") : String(localized: "v\(sheet.version) QA지"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summary(_ sheet: VersionSheet.Sheet) -> some View {
        let done = sheet.automatic.count + sheet.manual.count
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: Double(done), total: Double(max(sheet.total, 1)))
                .accessibilityHidden(true)
            Text("\(sheet.total)개 중 \(done)개 확인 · 자동 \(sheet.automatic.count) · 수동 \(sheet.manual.count)")
                .font(.body)
            if sheet.failCount > 0 {
                Label("실패 \(sheet.failCount)개", systemImage: Outcome.fail.symbol)
                    .font(.body)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func continueButton(_ sheet: VersionSheet.Sheet) -> some View {
        // 버전을 모르는 기록은 어느 버전으로 이어야 할지 몰라 이어서 채우지 않는다.
        if !sheet.pending.isEmpty, !sheet.version.isEmpty, !app.isArchived {
            Button {
                if app.versionUnderTest != sheet.version {
                    app.testingVersion = sheet.version
                    try? context.save()
                }
                router.startSession(app.id, continuingSheet: true)
            } label: {
                WideButtonLabel(title: String(localized: "남은 \(sheet.pending.count)개 이어서 채우기"), systemImage: "hand.raised.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("이 버전에서 이미 본 결과를 채워 두고 남은 항목만 손으로 확인합니다")
        }
    }

    @ViewBuilder
    private func rowsSection(_ rows: [VersionSheet.Row], title: LocalizedStringKey, systemImage: String, footer: LocalizedStringKey) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { SheetRow(row: $0) }
            } header: {
                HStack {
                    Label(title, systemImage: systemImage)
                    Spacer()
                    Text("\(rows.count)개").monospacedDigit()
                }
            } footer: {
                Text(footer)
            }
        }
    }
}

private struct SheetRow: View {
    let row: VersionSheet.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(row.title)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                mark
            }
            .font(.body)
            if !row.note.isEmpty {
                Text(row.outcome == nil ? String(localized: "Claude가 못 봤어요: \(row.note)") : row.note)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let data = row.screenshot, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("첨부한 스크린샷")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.outcome?.label ?? String(localized: "아직 안 함"))
    }

    @ViewBuilder
    private var mark: some View {
        if let outcome = row.outcome {
            Image(systemName: outcome.symbol).foregroundStyle(outcome.tint)
        } else {
            Image(systemName: "circle.dashed").foregroundStyle(.secondary)
        }
    }
}
