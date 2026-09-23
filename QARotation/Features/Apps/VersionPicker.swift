import SwiftUI

/// 이 앱에서 고를 만한 버전들. 스토어 버전, 지금 보던 버전, 예전에 QA한 버전을 모은다.
enum VersionOptions {
    static func candidates(for app: TrackedApp) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ value: String) {
            let version = value.trimmingCharacters(in: .whitespaces)
            guard !version.isEmpty, seen.insert(version).inserted else { return }
            result.append(version)
        }
        add(app.currentVersion)
        add(app.versionUnderTest)
        for session in app.sortedSessions { add(session.appVersion) }
        return result
    }

    /// 무엇인지 한눈에 알아보게 붙이는 말.
    static func note(for version: String, app: TrackedApp) -> String? {
        var notes: [String] = []
        if version == app.currentVersion { notes.append("스토어 최신") }
        if version == app.versionUnderTest { notes.append("지금 보는 중") }
        let count = app.sortedSessions.filter { $0.appVersion == version }.count
        if count > 0 { notes.append("QA \(count)회") }
        return notes.isEmpty ? nil : notes.joined(separator: " · ")
    }
}

/// 테스트할 버전을 고르는 시트. 목록에 없으면 직접 적는다.
struct VersionPicker: View {
    let app: TrackedApp
    @Binding var version: String
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(VersionOptions.candidates(for: app), id: \.self) { candidate in
                        Button {
                            version = candidate
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("v\(candidate)")
                                    if let note = VersionOptions.note(for: candidate, app: app) {
                                        Text(note).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if candidate == version {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("고르기")
                } footer: {
                    Text("고른 버전은 이번 QA 기록에 남고, 다음 QA에도 이어집니다.")
                }

                Section("직접 적기") {
                    HStack {
                        TextField("예: 5.1.5", text: $typed)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(useTyped)
                        Button("쓰기", action: useTyped)
                            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("테스트할 버전")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func useTyped() {
        let value = typed.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        version = value
        dismiss()
    }
}
