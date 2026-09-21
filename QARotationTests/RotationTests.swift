import Foundation
import Testing
@testable import QARotation

@Suite("로테이션")
struct RotationTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()
    let now = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21 경

    func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    func app(
        _ name: String,
        tier: Tier = .normal,
        last: Int? = nil,
        created: Int = 100,
        archived: Bool = false
    ) -> RotationCandidate {
        RotationCandidate(
            id: UUID(),
            name: name,
            tier: tier,
            lastQADate: last.map(daysAgo),
            createdAt: daysAgo(created),
            isArchived: archived
        )
    }

    func ranked(_ apps: [RotationCandidate], weights: TierWeights = .standard) -> [String] {
        Rotation.ranked(apps, now: now, weights: weights, calendar: calendar).map(\.name)
    }

    @Test func 보관된_앱은_추천하지_않는다() {
        let apps = [
            app("보관", last: 300, archived: true),
            app("보관-미검사", archived: true),
            app("일반", last: 1),
        ]
        #expect(ranked(apps) == ["일반"])
        #expect(Rotation.pick(from: apps, now: now, weights: .standard, calendar: calendar)?.name == "일반")
    }

    @Test func 모두_보관이면_추천이_없다() {
        let apps = [app("A", archived: true)]
        #expect(Rotation.pick(from: apps, now: now, weights: .standard, calendar: calendar) == nil)
    }

    @Test func 한_번도_안_한_앱이_먼저다() {
        let apps = [
            app("오래됨-높음", tier: .high, last: 200),
            app("미검사-낮음", tier: .low),
        ]
        #expect(ranked(apps) == ["미검사-낮음", "오래됨-높음"])
    }

    @Test func 새로_가져온_앱이_맨_앞이다() {
        let apps = [
            app("예전에-들어온-미검사", created: 30),
            app("방금-가져옴", created: 0),
            app("오래됨", last: 90),
        ]
        #expect(ranked(apps).first == "방금-가져옴")
    }

    @Test func 같은_날_들어온_미검사는_등급과_이름순이다() {
        let apps = [
            app("나", tier: .normal, created: 0),
            app("가", tier: .normal, created: 0),
            app("다", tier: .high, created: 0),
        ]
        #expect(ranked(apps) == ["다", "가", "나"])
    }

    @Test func 점수는_일수_곱하기_가중치다() {
        // 높음 10일 = 20, 보통 15일 = 15, 낮음 30일 = 15 → 동점이면 더 오래된 쪽
        let apps = [
            app("보통15", tier: .normal, last: 15),
            app("낮음30", tier: .low, last: 30),
            app("높음10", tier: .high, last: 10),
        ]
        #expect(ranked(apps) == ["높음10", "낮음30", "보통15"])
    }

    @Test func 가중치를_바꾸면_순서가_바뀐다() {
        let apps = [
            app("높음10", tier: .high, last: 10),
            app("보통15", tier: .normal, last: 15),
        ]
        let flat = TierWeights(high: 1, normal: 1, low: 1)
        #expect(ranked(apps, weights: flat) == ["보통15", "높음10"])
    }

    @Test func 오늘_한_앱은_점수가_0이다() {
        let today = app("오늘", tier: .high, last: 0)
        #expect(Rotation.score(for: today, now: now, weights: .standard, calendar: calendar) == 0)
    }

    @Test func 건너뛰면_다음_후보를_준다() {
        let first = app("첫째", last: 30)
        let second = app("둘째", last: 20)
        let apps = [first, second]
        let pick = Rotation.pick(from: apps, now: now, weights: .standard, skipped: [first.id], calendar: calendar)
        #expect(pick?.id == second.id)
    }

    @Test func 전부_건너뛰면_처음으로_돌아간다() {
        let first = app("첫째", last: 30)
        let second = app("둘째", last: 20)
        let pick = Rotation.pick(from: [first, second], now: now, weights: .standard, skipped: [first.id, second.id], calendar: calendar)
        #expect(pick?.id == first.id)
    }

    @Test func 일수는_달력_날짜로_센다() {
        let lateLastNight = calendar.date(bySettingHour: 23, minute: 50, second: 0, of: daysAgo(1))!
        let earlyToday = calendar.date(bySettingHour: 0, minute: 10, second: 0, of: now)!
        #expect(Rotation.daysSince(lateLastNight, now: earlyToday, calendar: calendar) == 1)
        #expect(Rotation.daysSince(now, now: now, calendar: calendar) == 0)
        #expect(Rotation.daysSince(now.addingTimeInterval(86_400 * 3), now: now, calendar: calendar) == 0)
    }

    @Test func 밀린_앱은_21일을_넘긴_것만_센다() {
        let apps = [
            app("21일", last: 21),
            app("22일", last: 22),
            app("미검사"),
            app("보관-100일", last: 100, archived: true),
        ]
        #expect(Rotation.overdueCount(apps, now: now, calendar: calendar) == 1)
        #expect(Rotation.neverQACount(apps) == 1)
    }
}

@Suite("사이클 진행")
struct CycleProgressTests {
    let a = UUID(), b = UUID(), c = UUID()
    let base = Date(timeIntervalSince1970: 1_790_000_000)

    func stamp(_ id: UUID, _ day: Int) -> SessionStamp {
        SessionStamp(appID: id, date: base.addingTimeInterval(Double(day) * 86_400))
    }

    @Test func 기록이_없으면_0이다() {
        let p = Rotation.cycleProgress(sessions: [], activeAppIDs: [a, b, c])
        #expect(p == CycleProgress(done: 0, total: 3, completedCycles: 0))
    }

    @Test func 같은_앱을_두_번_해도_한_번으로_센다() {
        let p = Rotation.cycleProgress(sessions: [stamp(a, 0), stamp(a, 1), stamp(b, 2)], activeAppIDs: [a, b, c])
        #expect(p.done == 2)
    }

    @Test func 한_바퀴를_다_돌면_새_사이클이다() {
        let sessions = [stamp(a, 0), stamp(b, 1), stamp(c, 2), stamp(b, 3)]
        let p = Rotation.cycleProgress(sessions: sessions.shuffled(), activeAppIDs: [a, b, c])
        #expect(p == CycleProgress(done: 1, total: 3, completedCycles: 1))
    }

    @Test func 로테이션에_없는_앱의_기록은_무시한다() {
        let archived = UUID()
        let p = Rotation.cycleProgress(sessions: [stamp(archived, 0), stamp(a, 1)], activeAppIDs: [a, b])
        #expect(p.done == 1)
    }
}

@Suite("건너뛰기 저장", .serialized)
struct SkipStoreTests {
    let defaults: UserDefaults = {
        let d = UserDefaults(suiteName: "SkipStoreTests")!
        d.removePersistentDomain(forName: "SkipStoreTests")
        return d
    }()
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func 오늘_건너뛴_것만_기억한다() {
        let store = SkipStore(defaults: defaults)
        let id = UUID()
        store.skip(id, now: now, allCandidateIDs: [id, UUID()])
        #expect(store.skipped(on: now) == [id])
        #expect(store.skipped(on: now.addingTimeInterval(86_400 * 2)).isEmpty)
    }

    @Test func 전부_건너뛰면_방금_것만_남긴다() {
        let store = SkipStore(defaults: defaults)
        let a = UUID(), b = UUID()
        store.skip(a, now: now, allCandidateIDs: [a, b])
        store.skip(b, now: now, allCandidateIDs: [a, b])
        #expect(store.skipped(on: now) == [b])
    }
}
