import SwiftData
import SwiftUI

struct IssueDetailView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @State private var showingScreenshot = false

    private var statusBinding: Binding<IssueStatus> {
        Binding(get: { issue.status }, set: { issue.setStatus($0); try? context.save() })
    }

    var body: some View {
        Form {
            Section {
                Picker("상태", selection: statusBinding) {
                    ForEach(IssueStatus.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                if let resolvedAt = issue.resolvedAt {
                    Text("\(resolvedAt.formatted(date: .abbreviated, time: .omitted))에 정리")
                }
            }

            Section("내용") {
                LabeledContent("앱", value: issue.app?.name ?? "-")
                LabeledContent("항목", value: issue.title)
                LabeledContent("분류", value: issue.category.label)
                LabeledContent("발견", value: issue.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let session = issue.sourceResult?.session {
                    LabeledContent("테스트한 버전", value: session.appVersion.isEmpty ? "-" : session.appVersion)
                    LabeledContent("기기", value: session.deviceModel)
                }
            }

            Section("메모") {
                TextField("메모", text: $issue.note, axis: .vertical)
                    .onSubmit { try? context.save() }
            }

            if let data = issue.screenshot, let image = UIImage(data: data) {
                Section("스크린샷") {
                    Button {
                        showingScreenshot = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("스크린샷 크게 보기")
                    .fullScreenCover(isPresented: $showingScreenshot) {
                        ScreenshotViewer(image: image)
                    }
                }
            }
        }
        .navigationTitle(issue.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }
}

private struct ScreenshotViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .accessibilityLabel("스크린샷")
                .toolbar { Button("닫기") { dismiss() } }
        }
    }
}
