import SwiftData
import SwiftUI

@main
struct QARotationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var router = Router.shared
    @State private var importer = ImportController()
    private let container: ModelContainer

    init() {
        AppSettings.registerDefaults()
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("저장소를 열 수 없습니다: \(error)")
        }
        ChecklistSeeder.seedIfNeeded(container.mainContext)
        ChecklistSeeder.fillMissingSteps(container.mainContext)
        BundledAppsSeeder.seedIfNeeded(container.mainContext)
        AppChecklistSeeder.seedNewItems(container.mainContext)
        PickChangeCoordinator.pickDidChange(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(importer)
                .onOpenURL { router.handle($0) }
        }
        .modelContainer(container)
    }
}
