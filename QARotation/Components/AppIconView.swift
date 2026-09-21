import SwiftUI

struct AppIconView: View {
    let name: String
    let iconData: Data?
    let iconURL: String
    var size: CGFloat

    init(app: TrackedApp, size: CGFloat) {
        self.name = app.name
        self.iconData = app.iconData
        self.iconURL = app.iconURL
        self.size = size
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let iconData, let image = UIImage(data: iconData) {
            Image(uiImage: image).resizable().interpolation(.high)
        } else if let url = URL(string: iconURL), !iconURL.isEmpty {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [.accentColor.opacity(0.7), .accentColor], startPoint: .top, endPoint: .bottom)
            Text(name.prefix(1))
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
