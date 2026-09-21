import SwiftData
import SwiftUI
import WidgetKit

struct PickEntry: TimelineEntry {
    let date: Date
    let appID: UUID?
    let name: String?
    let lastQADate: Date?
    let iconData: Data?

    static let placeholder = PickEntry(date: .now, appID: UUID(), name: "클립키보드", lastQADate: .now.addingTimeInterval(-86_400 * 12), iconData: nil)
    static let empty = PickEntry(date: .now, appID: nil, name: nil, lastQADate: nil, iconData: nil)

    var url: URL {
        appID.map { DeepLink.session($0).url } ?? DeepLink.today.url
    }

    var daysText: String {
        guard let lastQADate else { return "아직 안 함" }
        let days = Rotation.daysSince(lastQADate, now: date)
        return days == 0 ? "오늘 함" : "\(days)일 전"
    }
}

struct PickProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PickEntry) -> Void) {
        completion(context.isPreview ? .placeholder : Self.loadEntry(now: .now))
    }

    /// 일수가 바뀌는 자정에 다시 계산한다. 앱에서 QA·건너뛰기를 하면 그때도 새로 불린다.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PickEntry>) -> Void) {
        let now = Date.now
        let entry = Self.loadEntry(now: now)
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    static func loadEntry(now: Date) -> PickEntry {
        AppSettings.registerDefaults()
        guard let container = try? Persistence.makeContainer() else { return .empty }
        let context = ModelContext(container)
        guard let app = try? PickResolver.currentPick(in: context, now: now) else { return .empty }
        return PickEntry(date: now, appID: app.id, name: app.name, lastQADate: app.lastQADate, iconData: app.iconData)
    }
}

struct TodayPickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayPick", provider: PickProvider()) { entry in
            TodayPickWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.url)
        }
        .configurationDisplayName("오늘의 QA")
        .description("오늘 QA할 앱을 보여 주고, 누르면 바로 체크리스트가 열려요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct TodayPickWidgetView: View {
    let entry: PickEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let name = entry.name {
            switch family {
            case .accessoryInline:
                Text("QA: \(name) · \(entry.daysText)")
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label("오늘의 QA", systemImage: "checklist").font(.caption2).widgetAccentable()
                    Text(name).font(.headline).lineLimit(1)
                    Text(entry.daysText).font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .systemMedium:
                HStack(spacing: 16) {
                    icon(size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("오늘의 QA").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(name).font(.title3.bold()).lineLimit(2)
                        Text("마지막 QA \(entry.daysText)").font(.subheadline).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Label("눌러서 시작", systemImage: "play.fill").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                    }
                    Spacer(minLength: 0)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    icon(size: 48)
                    Spacer(minLength: 0)
                    Text(name).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                    Text(entry.daysText).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                if family != .accessoryCircular {
                    Text("앱을 가져와 주세요").font(.caption)
                }
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                if let lastQADate = entry.lastQADate {
                    Text("\(Rotation.daysSince(lastQADate, now: entry.date))")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("일").font(.caption2)
                } else {
                    Image(systemName: "sparkles").font(.title3)
                    Text("새 앱").font(.caption2)
                }
            }
        }
        .accessibilityLabel("\(entry.name ?? ""), \(entry.daysText)")
    }

    @ViewBuilder
    private func icon(size: CGFloat) -> some View {
        Group {
            if let data = entry.iconData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable()
            } else {
                RoundedRectangle(cornerRadius: size * 0.22).fill(.tint)
                    .overlay {
                        Text(entry.name?.prefix(1) ?? "")
                            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        .accessibilityHidden(true)
    }
}

@main
struct QARotationWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayPickWidget()
    }
}
