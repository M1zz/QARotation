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
            AppChecklistSeeder.seedNewApps(context)
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
