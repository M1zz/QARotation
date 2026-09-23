import SwiftUI

struct SessionHeaderView: View {
    @Bindable var model: SessionViewModel
    @State private var pickingVersion = false
    @Environment(\.openURL) private var openURL
    @ScaledMetric private var scaledIconSize: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var iconSize: CGFloat { min(scaledIconSize, 72) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                AppIconView(app: model.app, size: iconSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.app.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        pickingVersion = true
                    } label: {
                        Label(
                            model.meta.appVersion.isEmpty ? "테스트할 버전 고르기" : "테스트 중 v\(model.meta.appVersion)",
                            systemImage: "chevron.down"
                        )
                        .labelStyle(TrailingIconLabelStyle())
                        .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("다른 버전으로 바꿉니다")
                }
            }

            if let url = model.app.launchURL ?? model.app.storeURL {
                Button {
                    openApp(primary: url)
                } label: {
                    WideButtonLabel(
                        title: model.app.launchURL == nil ? "App Store에서 열기" : "앱 열기",
                        systemImage: "arrow.up.forward.app"
                    )
                }
                .buttonStyle(.bordered)
            }

            DisclosureGroup("기록 정보") {
                LabeledTextField(title: "앱 버전", text: $model.meta.appVersion)
                LabeledTextField(title: "기기", text: $model.meta.deviceModel)
                LabeledTextField(title: "OS", text: $model.meta.osVersion)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $pickingVersion) {
            VersionPicker(app: model.app, version: $model.meta.appVersion)
        }
        .onChange(of: model.meta.appVersion) { _, _ in
            if model.hasProgress { model.keepDraft() }
        }
    }

    /// URL 스킴으로 못 열면(앱이 안 깔렸거나 스킴이 틀림) App Store 로 보낸다.
    private func openApp(primary: URL) {
        let fallback = model.app.storeURL
        let open = openURL
        open(primary) { accepted in
            if !accepted, let fallback, fallback != primary {
                open(fallback)
            }
        }
    }
}

private struct LabeledTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}
