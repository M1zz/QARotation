import Foundation

/// 한 버전의 QA지. 그 버전의 기록을 모두 겹쳐 항목마다 가장 최근 결과 하나를 남긴다.
/// 맥에서 Claude 가 자동으로 본 것, 사람이 손으로 본 것, 아직 아무도 안 본 것으로 나눈다.
@MainActor
enum VersionSheet {
    enum Source {
        case automatic, manual
    }

    struct Row: Identifiable {
        let title: String
        let steps: String
        let category: ChecklistCategory
        let outcome: Outcome?
        let source: Source?
        /// 본 항목은 그때 남긴 메모, 안 본 항목은 Claude 가 못 본 이유.
        let note: String
        let screenshot: Data?
        let date: Date?
        var id: String { title }
    }

    struct Sheet {
        let version: String
        let automatic: [Row]
        let manual: [Row]
        let pending: [Row]

        var total: Int { automatic.count + manual.count + pending.count }
        var failCount: Int { (automatic + manual).filter { $0.outcome == .fail }.count }

        /// 이어서 채울 세션에 미리 넣을 결과. 실패는 이슈로 다시 확인하므로 `prefill` 이 거른다.
        var carried: [String: CarriedResult] {
            Dictionary(
                (automatic + manual).compactMap { row in
                    row.outcome.map { (row.title, CarriedResult(outcome: $0, note: row.note, byClaude: row.source == .automatic)) }
                },
                uniquingKeysWith: { first, _ in first }
            )
        }

        /// 아직 안 본 항목에 붙은 Claude 의 이유.
        var uncheckedNotes: [String: String] {
            Dictionary(pending.filter { !$0.note.isEmpty }.map { ($0.title, $0.note) }, uniquingKeysWith: { first, _ in first })
        }
    }

    /// 체크리스트 순서를 따르고, 체크리스트에서 빠졌지만 이 버전에 기록이 남은 항목은 뒤에 붙인다.
    static func build(version: String, sessions: [QASession], checklist: [DraftResult]) -> Sheet {
        let target = version.trimmingCharacters(in: .whitespaces)
        let mine = sessions
            .filter { $0.appVersion.trimmingCharacters(in: .whitespaces) == target }
            .sorted { $0.date < $1.date }

        var latest: [String: (result: ItemResult, session: QASession)] = [:]
        for session in mine {
            for result in session.results ?? [] { latest[result.itemTitle] = (result, session) }
        }
        let unchecked = mine.last(where: \.byClaude)?.claudeUncheckedNotes ?? [:]

        func row(title: String, steps: String, category: ChecklistCategory) -> Row {
            guard let (result, session) = latest[title] else {
                return Row(title: title, steps: steps, category: category, outcome: nil, source: nil,
                           note: unchecked[title] ?? "", screenshot: nil, date: nil)
            }
            return Row(
                title: title,
                steps: steps,
                category: category,
                outcome: result.outcome,
                source: result.byClaude || session.byClaude ? .automatic : .manual,
                note: result.note,
                screenshot: result.screenshot,
                date: session.date
            )
        }

        let known = Set(checklist.map(\.title))
        let leftovers = latest.values
            .filter { !known.contains($0.result.itemTitle) }
            .sorted { ($0.result.category.sortIndex, $0.result.order) < ($1.result.category.sortIndex, $1.result.order) }
        let rows = checklist.map { row(title: $0.title, steps: $0.steps, category: $0.category) }
            + leftovers.map { row(title: $0.result.itemTitle, steps: "", category: $0.result.category) }

        return Sheet(
            version: target,
            automatic: rows.filter { $0.source == .automatic },
            manual: rows.filter { $0.source == .manual },
            pending: rows.filter { $0.source == nil }
        )
    }
}
