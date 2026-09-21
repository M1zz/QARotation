import SwiftData
import SwiftUI

/// 직접 추가하거나 스토어 정보를 손으로 고칠 때 쓴다.
struct AppEditView: View {
    let app: TrackedApp?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var appStoreID = ""
    @State private var bundleID = ""
    @State private var version = ""
    @State private var iconURL = ""
    @State private var tier: Tier = .normal
    @State private var urlScheme = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("앱 이름", text: $name)
                    TextField("App Store ID (숫자)", text: $appStoreID)
                        .keyboardType(.numberPad)
                    TextField("번들 ID", text: $bundleID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("현재 버전", text: $version)
                        .keyboardType(.decimalPad)
                    TextField("아이콘 URL", text: $iconURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("App Store에서 새로고침하면 이름·번들 ID·버전·아이콘은 스토어 값으로 바뀝니다.")
                }

                Section {
                    Picker("우선순위", selection: $tier) {
                        ForEach(Tier.allCases) { Text($0.label).tag($0) }
                    }
                    TextField("URL 스킴 (예: myapp)", text: $urlScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

            }
            .navigationTitle(app == nil ? "앱 추가" : "앱 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let app else { return }
        name = app.name
        appStoreID = app.appStoreID
        bundleID = app.bundleID
        version = app.currentVersion
        iconURL = app.iconURL
        tier = app.tier
        urlScheme = app.urlScheme
    }

    private func save() {
        let target = app ?? {
            let new = TrackedApp(name: "")
            context.insert(new)
            return new
        }()
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.appStoreID = appStoreID.trimmingCharacters(in: .whitespaces)
        target.bundleID = bundleID.trimmingCharacters(in: .whitespaces)
        target.currentVersion = version.trimmingCharacters(in: .whitespaces)
        let trimmedIcon = iconURL.trimmingCharacters(in: .whitespaces)
        if target.iconURL != trimmedIcon {
            target.iconURL = trimmedIcon
            target.iconData = nil
        }
        target.tier = tier
        target.urlScheme = urlScheme.trimmingCharacters(in: .whitespaces)
        try? context.save()
        PickChangeCoordinator.pickDidChange(context: context)
        Task { try? await AppImporter.downloadMissingIcons(in: context) }
        dismiss()
    }
}
