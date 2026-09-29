import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ImportController {
    struct Message: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private(set) var isRunning = false
    var message: Message?

    /// 맥에서 Claude 가 만든 결과지(json, 스크린샷 PNG)를 넣는다. 넣은 기록은 오늘 탭 카드로 이어서 본다.
    func importClaudeResults(_ urls: [URL], context: ModelContext) {
        let summary = ClaudeQASeeder.importFiles(urls, into: context)
        PickChangeCoordinator.pickDidChange(context: context)

        var lines: [String] = []
        if !summary.imported.isEmpty {
            lines.append(String(localized: "\(summary.imported.joined(separator: ", ")) 결과지를 넣었어요. 오늘 탭에서 이어서 QA하세요."))
        }
        if summary.duplicates > 0 {
            lines.append(String(localized: "이미 넣은 결과지 \(summary.duplicates)개는 건너뛰었어요."))
        }
        if !summary.unknownApps.isEmpty {
            lines.append(String(localized: "앱 목록에 없는 번들 ID예요: \(summary.unknownApps.joined(separator: ", "))"))
        }
        if !summary.unreadable.isEmpty {
            lines.append(String(localized: "읽지 못한 파일: \(summary.unreadable.joined(separator: ", "))"))
        }
        message = Message(
            title: summary.imported.isEmpty ? String(localized: "넣은 결과지가 없어요") : String(localized: "결과지를 가져왔어요"),
            body: lines.isEmpty ? String(localized: "Claude QA 결과지(json)를 골라 주세요.") : lines.joined(separator: "\n")
        )
    }

    func run(context: ModelContext) async {
        guard !isRunning else { return }
        let artistID = AppSettings.artistID()
        guard !artistID.isEmpty else {
            message = Message(title: "개발자 ID가 없어요", body: "설정 ▸ App Store 에서 artistId를 입력해 주세요.")
            return
        }

        isRunning = true
        defer { isRunning = false }

        do {
            let fetched = try await ITunesLookupClient().fetchApps(artistID: artistID, storefronts: AppSettings.storefronts())
            let summary = try AppImporter.apply(fetched, to: context)
            AppChecklistSeeder.seedNewItems(context)
            ClaudeQASeeder.seedIfNeeded(context)
            BundledAppsSeeder.fillMissingIcons(context)
            try? await AppImporter.downloadMissingIcons(in: context)
            PickChangeCoordinator.pickDidChange(context: context)
            message = Message(
                title: "App Store에서 가져왔어요",
                body: "새 앱 \(summary.inserted)개, 바뀐 앱 \(summary.updated)개, 그대로 \(summary.unchanged)개"
            )
        } catch {
            message = Message(title: "가져오지 못했어요", body: error.localizedDescription)
        }
    }
}
