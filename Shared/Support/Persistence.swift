import Foundation
import SwiftData

enum AppGroup {
    static let id = "group.com.leeo.QARotation"
}

enum Persistence {
    static let schema = Schema([
        TrackedApp.self,
        ChecklistItem.self,
        QASession.self,
        ItemResult.self,
        Issue.self,
    ])

    /// 앱과 위젯이 같은 저장소를 보도록 App Group 컨테이너에 둔다.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        }
        do {
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.id), cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // 서명 없이 돌려서 App Group 을 못 쓰는 경우. 앱은 돌지만 위젯은 데이터를 못 본다.
            let config = ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: config)
        }
    }
}

extension UserDefaults {
    /// 앱과 위젯이 함께 읽는 설정 저장소.
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }
}
