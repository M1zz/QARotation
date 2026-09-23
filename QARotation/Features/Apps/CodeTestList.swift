import Foundation

/// 코드로 확인할 수 있는 항목만 모아 붙여넣기 좋은 글로 만든다.
/// QA를 돌다 "이건 테스트로 막자" 싶을 때, 이 글을 그대로 개발 도구에 넘기면 된다.
enum CodeTestList {
    static func text(for app: TrackedApp) -> String {
        let items = app.sortedExtraItems.filter { $0.verification.isAutomatable }
        guard !items.isEmpty else { return "" }

        var lines = ["\(app.name) 자동화할 QA 항목"]
        if !app.bundleID.isEmpty { lines.append("번들 ID: \(app.bundleID)") }
        if !app.versionUnderTest.isEmpty { lines.append("테스트 중인 버전: \(app.versionUnderTest)") }
        lines.append("")

        for kind in [Verification.unit, .ui] {
            let group = items.filter { $0.verification == kind }
            guard !group.isEmpty else { continue }
            lines.append("## \(kind.label) (\(group.count)개)")
            for item in group {
                lines.append("- \(item.title)")
                if !item.steps.isEmpty { lines.append("  확인: \(item.steps)") }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
