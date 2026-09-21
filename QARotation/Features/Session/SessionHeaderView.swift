import SwiftUI

struct SessionHeaderView: View {
    @Bindable var model: SessionViewModel
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
                    SessionTimerView(startedAt: model.meta.startedAt, limitSeconds: model.timerSeconds)
                }
            }

            if let url = model.app.launchURL ?? model.app.storeURL {
                Button {
                    openApp(primary: url)
                } label: {
                    Label(model.app.launchURL == nil ? "App Store에서 열기" : "앱 열기", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity, minHeight: 44)
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

/// 부드러운 제한 시간. 넘겨도 막지 않고 빨갛게 초과 시간을 보여 준다.
struct SessionTimerView: View {
    let startedAt: Date
    let limitSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
            let remaining = limitSeconds - elapsed
            let shown = abs(remaining)
            let text = String(format: "%@%d:%02d", remaining < 0 ? "+" : "", shown / 60, shown % 60)
            HStack(spacing: 6) {
                Image(systemName: remaining < 0 ? "timer.circle.fill" : "timer")
                Text(text).lineLimit(1)
            }
                .font(.subheadline.weight(.semibold))
                .accessibilityElement(children: .ignore)
                .monospacedDigit()
                .foregroundStyle(remaining < 0 ? .red : remaining < 60 ? .orange : .secondary)
                .accessibilityLabel(remaining < 0 ? "제한 시간 \(shown / 60)분 \(shown % 60)초 초과" : "남은 시간 \(shown / 60)분 \(shown % 60)초")
        }
    }
}
