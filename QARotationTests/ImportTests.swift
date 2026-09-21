import Foundation
import SwiftData
import Testing
@testable import QARotation

@Suite("iTunes 가져오기")
struct ImportParsingTests {
    let sample = Data("""
    {"resultCount":3,"results":[
      {"wrapperType":"artist","artistType":"Software Artist","artistName":"hyunho lee","artistId":1502508537},
      {"wrapperType":"software","kind":"software","trackId":1543660502,"trackName":"클립키보드","bundleId":"com.Ysoup.TokenMemo",
       "artworkUrl100":"https://example.com/100.jpg","artworkUrl512":"https://example.com/512.jpg","version":"5.1.4",
       "supportedDevices":["iPhone5s-iPhone5s","iPadAir-iPadAir","Watch4-Watch4"]},
      {"wrapperType":"software","kind":"mac-software","trackId":6755651803,"trackName":"맥앱","bundleId":"com.leeo.mac",
       "artworkUrl100":"https://example.com/m100.jpg","version":"1.0","supportedDevices":[]}
    ]}
    """.utf8)

    @Test func 개발자_항목은_빼고_앱만_읽는다() throws {
        let apps = try ITunesLookupClient.parse(sample)
        #expect(apps.count == 2)
        #expect(apps[0] == StoreApp(
            appStoreID: "1543660502",
            bundleID: "com.Ysoup.TokenMemo",
            name: "클립키보드",
            iconURL: "https://example.com/512.jpg",
            version: "5.1.4",
            platforms: [.iPhone, .iPad, .watch]
        ))
    }

    @Test func 맥_앱은_Mac_플랫폼이고_512가_없으면_100을_쓴다() throws {
        let mac = try #require(try ITunesLookupClient.parse(sample).last)
        #expect(mac.platforms == [.mac])
        #expect(mac.iconURL == "https://example.com/m100.jpg")
    }
}

@Suite("가져오기 병합")
struct ImportPlanTests {
    func store(_ id: String, bundle: String = "", name: String = "앱") -> StoreApp {
        StoreApp(appStoreID: id, bundleID: bundle, name: name, iconURL: "", version: "1.0", platforms: [.iPhone])
    }

    @Test func 스토어_ID로_먼저_짝짓는다() {
        let existing = ImportPlan.ExistingKey(id: UUID(), appStoreID: "1", bundleID: "b")
        let plan = ImportPlan.make(existing: [existing], fetched: [store("1", bundle: "다른번들")])
        #expect(plan.matches[existing.id]?.appStoreID == "1")
        #expect(plan.inserts.isEmpty)
    }

    @Test func 직접_추가한_앱은_번들_ID로_짝짓는다() {
        let manual = ImportPlan.ExistingKey(id: UUID(), appStoreID: "", bundleID: "com.leeo.a")
        let plan = ImportPlan.make(existing: [manual], fetched: [store("9", bundle: "com.leeo.a")])
        #expect(plan.matches[manual.id]?.appStoreID == "9")
    }

    @Test func 처음_보는_앱은_새로_넣고_없어진_앱은_건드리지_않는다() {
        let gone = ImportPlan.ExistingKey(id: UUID(), appStoreID: "old", bundleID: "com.old")
        let plan = ImportPlan.make(existing: [gone], fetched: [store("new")])
        #expect(plan.matches.isEmpty)
        #expect(plan.inserts.map(\.appStoreID) == ["new"])
    }
}

@Suite("가져오기 적용")
@MainActor
struct AppImporterTests {
    @Test func 사용자가_정한_값은_덮어쓰지_않는다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let app = TrackedApp(name: "옛이름", appStoreID: "1", currentVersion: "1.0")
        app.tier = .high
        app.notes = "메모"
        app.urlScheme = "myapp"
        app.isArchived = true
        context.insert(app)

        let fetched = [
            StoreApp(appStoreID: "1", bundleID: "com.a", name: "새이름", iconURL: "https://x/1.png", version: "2.0", platforms: [.iPhone]),
            StoreApp(appStoreID: "2", bundleID: "com.b", name: "새앱", iconURL: "", version: "1.0", platforms: [.iPad]),
        ]
        let summary = try AppImporter.apply(fetched, to: context)

        #expect(summary == ImportSummary(inserted: 1, updated: 1, unchanged: 0))
        #expect(app.name == "새이름")
        #expect(app.currentVersion == "2.0")
        #expect(app.tier == .high)
        #expect(app.notes == "메모")
        #expect(app.urlScheme == "myapp")
        #expect(app.isArchived)

        let again = try AppImporter.apply(fetched, to: context)
        #expect(again == ImportSummary(inserted: 0, updated: 0, unchanged: 2))
        #expect(try context.fetchCount(FetchDescriptor<TrackedApp>()) == 2)
    }

    @Test func 새로_가져온_앱이_로테이션_맨_앞에_온다() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let old = TrackedApp(name: "기존", appStoreID: "1", createdAt: .now.addingTimeInterval(-86_400 * 60))
        old.lastQADate = .now.addingTimeInterval(-86_400 * 50)
        context.insert(old)

        try AppImporter.apply([StoreApp(appStoreID: "2", bundleID: "", name: "신규", iconURL: "", version: "", platforms: [])], to: context)

        let apps = try context.fetch(FetchDescriptor<TrackedApp>())
        let pick = Rotation.pick(from: apps.map(\.rotationCandidate), now: .now, weights: .standard)
        #expect(pick?.name == "신규")
    }
}
