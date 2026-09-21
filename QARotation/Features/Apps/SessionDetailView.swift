import SwiftUI

struct SessionDetailView: View {
    let session: QASession

    var body: some View {
        List {
            Section("기록 정보") {
                LabeledContent("날짜", value: session.date.formatted(date: .long, time: .shortened))
                LabeledContent("걸린 시간", value: Duration.seconds(session.durationSeconds).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated)))
                LabeledContent("앱 버전", value: session.appVersion.isEmpty ? "-" : session.appVersion)
                LabeledContent("기기", value: session.deviceModel)
                LabeledContent("OS", value: session.osVersion)
            }

            let grouped = Dictionary(grouping: session.sortedResults, by: \.category)
            ForEach(ChecklistCategory.allCases.filter { grouped[$0] != nil }) { category in
                Section(category.label) {
                    ForEach(grouped[category] ?? []) { result in
                        ResultRow(result: result)
                    }
                }
            }
        }
        .navigationTitle(session.app?.name ?? "QA 기록")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ResultRow: View {
    let result: ItemResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(result.itemTitle)
            } icon: {
                Image(systemName: result.outcome.symbol).foregroundStyle(result.outcome.tint)
            }
            if !result.note.isEmpty {
                Text(result.note).font(.callout).foregroundStyle(.secondary)
            }
            if let data = result.screenshot, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("첨부한 스크린샷")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(result.outcome.label)
    }
}
