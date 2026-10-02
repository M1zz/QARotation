import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ImportController.self) private var importer
    @Query(filter: #Predicate<Issue> { $0.statusRaw == "open" }) private var openIssues: [Issue]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("오늘", systemImage: "sun.max", value: AppTab.today) {
                TodayView()
            }
            Tab("앱", systemImage: "square.grid.2x2", value: AppTab.apps) {
                AppsListView()
            }
            Tab("이슈", systemImage: "ladybug", value: AppTab.issues) {
                IssuesView()
            }
            .badge(openIssues.count)
            Tab("설정", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        // 아이패드에서는 위쪽 탭 막대를 왼쪽 사이드바로 펼칠 수 있다. 아이폰은 그대로 아래 탭 막대.
        .tabViewStyle(.sidebarAdaptable)
        .fullScreenCover(item: $router.activeSession) { route in
            QASessionView(appID: route.appID, continuesSheet: route.continuesSheet)
        }
        .importAlert(importer)
        #if DEBUG
        // 시뮬레이터 확인·스크린샷용: 실행 인자 -importOnLaunch 는 가져오기를, -deepLink <url> 은 위젯·알림과 같은 경로로 화면을,
        // -tab <today|apps|issues|settings> 는 그 탭을 연다.
        .task {
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = AppTab(rawValue: args[i + 1]) {
                router.selectedTab = tab
            }
            if CommandLine.arguments.contains("-importOnLaunch") { await importer.run(context: context) }
            if let i = CommandLine.arguments.firstIndex(of: "-deepLink"), i + 1 < CommandLine.arguments.count,
               let url = URL(string: CommandLine.arguments[i + 1]) {
                router.handle(url)
            }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            // 날짜가 바뀌면 추천도 바뀌므로 앱을 떠날 때 위젯과 알림을 맞춘다.
            if phase == .background { PickChangeCoordinator.pickDidChange(context: context) }
        }
    }
}
