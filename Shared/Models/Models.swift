import Foundation
import SwiftData

// CloudKit 동기화를 나중에 붙일 수 있게: 모든 속성에 기본값, 관계는 전부 옵셔널, unique 제약 없음.
// 열거형은 원시 문자열로 저장하고 계산 속성으로 감싼다(스키마가 열거형 정의에 묶이지 않도록).

@Model
final class TrackedApp {
    var id: UUID = UUID()
    var appStoreID: String = ""
    var bundleID: String = ""
    var name: String = ""
    var iconURL: String = ""
    @Attribute(.externalStorage) var iconData: Data?
    var currentVersion: String = ""
    var platformsRaw: [String] = []
    var tierRaw: String = Tier.normal.rawValue
    var urlScheme: String = ""
    /// 지금 테스트하고 있는 버전. 비어 있으면 스토어의 현재 버전을 쓴다.
    var testingVersion: String = ""
    var notes: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    /// 세션 기록에서 파생되는 값이지만, 정렬과 위젯 조회를 가볍게 하려고 따로 들고 있는다.
    var lastQADate: Date?

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.app)
    var extraChecklistItems: [ChecklistItem]? = []

    @Relationship(deleteRule: .cascade, inverse: \QASession.app)
    var sessions: [QASession]? = []

    @Relationship(deleteRule: .cascade, inverse: \Issue.app)
    var issues: [Issue]? = []

    init(
        name: String,
        appStoreID: String = "",
        bundleID: String = "",
        iconURL: String = "",
        currentVersion: String = "",
        platforms: [Platform] = [],
        tier: Tier = .normal,
        createdAt: Date = .now
    ) {
        self.name = name
        self.appStoreID = appStoreID
        self.bundleID = bundleID
        self.iconURL = iconURL
        self.currentVersion = currentVersion
        self.platformsRaw = platforms.map(\.rawValue)
        self.tierRaw = tier.rawValue
        self.createdAt = createdAt
    }

    var tier: Tier {
        get { Tier(rawValue: tierRaw) ?? .normal }
        set { tierRaw = newValue.rawValue }
    }

    var platforms: [Platform] {
        get { platformsRaw.compactMap(Platform.init(rawValue:)) }
        set { platformsRaw = newValue.map(\.rawValue) }
    }

    var sortedExtraItems: [ChecklistItem] {
        (extraChecklistItems ?? []).sorted { $0.order < $1.order }
    }

    var openIssues: [Issue] {
        (issues ?? []).filter { $0.status == .open }.sorted { $0.createdAt < $1.createdAt }
    }

    var sortedSessions: [QASession] {
        (sessions ?? []).sorted { $0.date > $1.date }
    }

    /// 이번 QA에 기록할 버전. 손으로 정한 값이 있으면 그것을, 없으면 스토어 버전을 쓴다.
    var versionUnderTest: String {
        let mine = testingVersion.trimmingCharacters(in: .whitespaces)
        return mine.isEmpty ? currentVersion : mine
    }

    /// 스토어에 이 앱의 더 새 버전이 올라와 있고, 그것을 아직 테스트하고 있지 않은 상태.
    var hasNewerStoreVersion: Bool {
        !currentVersion.isEmpty && !versionUnderTest.isEmpty && versionUnderTest != currentVersion
    }

    var storeURL: URL? {
        let id = appStoreID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }

    /// "myapp" 과 "myapp://" 둘 다 받아 준다.
    var launchURL: URL? {
        let scheme = urlScheme.trimmingCharacters(in: .whitespaces)
        guard !scheme.isEmpty else { return nil }
        return URL(string: scheme.contains("://") ? scheme : "\(scheme)://")
    }

    var rotationCandidate: RotationCandidate {
        RotationCandidate(
            id: id,
            name: name,
            tier: tier,
            lastQADate: lastQADate,
            createdAt: createdAt,
            isArchived: isArchived
        )
    }
}

@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var title: String = ""
    /// 어떻게 확인하는지를 "여는 화면 → 하는 일 → 기대 결과" 순서로 적어 둔다. 비어 있어도 된다.
    var steps: String = ""
    var categoryRaw: String = ChecklistCategory.custom.rawValue
    /// 코드로 확인할 수 있는 항목인지. 기본은 손으로 확인.
    var verificationRaw: String = Verification.manual.rawValue
    var order: Int = 0
    var isDefault: Bool = true
    /// 앱 전용 항목일 때만 값이 있다.
    var app: TrackedApp?

    init(
        title: String,
        steps: String = "",
        category: ChecklistCategory,
        verification: Verification = .manual,
        order: Int,
        isDefault: Bool
    ) {
        self.title = title
        self.steps = steps
        self.categoryRaw = category.rawValue
        self.verificationRaw = verification.rawValue
        self.order = order
        self.isDefault = isDefault
    }

    var category: ChecklistCategory {
        get { ChecklistCategory(rawValue: categoryRaw) ?? .custom }
        set { categoryRaw = newValue.rawValue }
    }

    var verification: Verification {
        get { Verification(rawValue: verificationRaw) ?? .manual }
        set { verificationRaw = newValue.rawValue }
    }
}

@Model
final class QASession {
    var id: UUID = UUID()
    var app: TrackedApp?
    var date: Date = Date.now
    var deviceModel: String = ""
    var osVersion: String = ""
    var appVersion: String = ""
    var durationSeconds: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \ItemResult.session)
    var results: [ItemResult]? = []

    init(date: Date, deviceModel: String, osVersion: String, appVersion: String, durationSeconds: Int) {
        self.date = date
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.durationSeconds = durationSeconds
    }

    var sortedResults: [ItemResult] {
        (results ?? []).sorted { $0.order < $1.order }
    }

    func count(of outcome: Outcome) -> Int {
        (results ?? []).filter { $0.outcome == outcome }.count
    }
}

@Model
final class ItemResult {
    var id: UUID = UUID()
    var session: QASession?
    /// 체크리스트를 고쳐도 과거 기록이 바뀌지 않도록 제목을 복사해 둔다.
    var itemTitle: String = ""
    var categoryRaw: String = ChecklistCategory.custom.rawValue
    var order: Int = 0
    var outcomeRaw: String = Outcome.pass.rawValue
    var note: String = ""
    @Attribute(.externalStorage) var screenshot: Data?

    @Relationship(deleteRule: .nullify, inverse: \Issue.sourceResult)
    var issues: [Issue]? = []

    init(itemTitle: String, category: ChecklistCategory, order: Int, outcome: Outcome, note: String, screenshot: Data?) {
        self.itemTitle = itemTitle
        self.categoryRaw = category.rawValue
        self.order = order
        self.outcomeRaw = outcome.rawValue
        self.note = note
        self.screenshot = screenshot
    }

    var category: ChecklistCategory { ChecklistCategory(rawValue: categoryRaw) ?? .custom }
    var outcome: Outcome { Outcome(rawValue: outcomeRaw) ?? .na }
}

@Model
final class Issue {
    var id: UUID = UUID()
    var app: TrackedApp?
    var sourceResult: ItemResult?
    var title: String = ""
    var categoryRaw: String = ChecklistCategory.custom.rawValue
    var note: String = ""
    @Attribute(.externalStorage) var screenshot: Data?
    var statusRaw: String = IssueStatus.open.rawValue
    var createdAt: Date = Date.now
    var resolvedAt: Date?

    init(title: String, category: ChecklistCategory, note: String, screenshot: Data?, createdAt: Date) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.note = note
        self.screenshot = screenshot
        self.createdAt = createdAt
    }

    var status: IssueStatus { IssueStatus(rawValue: statusRaw) ?? .open }
    var category: ChecklistCategory { ChecklistCategory(rawValue: categoryRaw) ?? .custom }

    func setStatus(_ newValue: IssueStatus, now: Date = .now) {
        guard newValue != status else { return }
        statusRaw = newValue.rawValue
        resolvedAt = newValue == .open ? nil : now
    }
}
