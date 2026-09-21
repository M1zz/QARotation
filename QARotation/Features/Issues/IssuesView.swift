import SwiftData
import SwiftUI

struct IssuesView: View {
    @Query(sort: \Issue.createdAt, order: .reverse) private var issues: [Issue]
    @State private var filter: IssueStatus = .open

    var body: some View {
        NavigationStack {
            let shown = issues.filter { $0.status == filter }
            List {
                Section {
                    Picker("상태", selection: $filter) {
                        ForEach(IssueStatus.allCases) { status in
                            Text("\(status.label) \(issues.filter { $0.status == status }.count)").tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(shown) { issue in
                        NavigationLink {
                            IssueDetailView(issue: issue)
                        } label: {
                            IssueRow(issue: issue, showsApp: true)
                        }
                    }
                }
            }
            .navigationTitle("이슈")
            .overlay {
                if shown.isEmpty {
                    ContentUnavailableView(emptyTitle, systemImage: "ladybug", description: Text(emptyDescription))
                }
            }
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .open: "열린 이슈가 없어요"
        case .fixed: "고친 이슈가 없어요"
        case .wontFix: "안 고치기로 한 이슈가 없어요"
        }
    }

    private var emptyDescription: String {
        filter == .open ? "QA에서 실패한 항목이 여기에 쌓여요." : ""
    }
}

struct IssueRow: View {
    let issue: Issue
    let showsApp: Bool
    @ScaledMetric private var iconSize: CGFloat = 36

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsApp, let app = issue.app {
                AppIconView(app: app, size: iconSize)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(issue.title).font(.body.weight(.medium))
                if showsApp, let app = issue.app {
                    Text(app.name).font(.subheadline).foregroundStyle(.secondary)
                }
                if !issue.note.isEmpty {
                    Text(issue.note).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
                HStack(spacing: 6) {
                    if issue.status != .open || !showsApp {
                        Text(issue.status.label)
                    }
                    Text(issue.createdAt, format: .relative(presentation: .named))
                    if issue.screenshot != nil {
                        Image(systemName: "photo").accessibilityLabel("스크린샷 있음")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
