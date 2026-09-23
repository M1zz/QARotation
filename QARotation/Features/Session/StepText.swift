import Foundation

/// 확인 단계는 "여는 곳 → 하는 일 → 기대 결과" 한 줄로 적혀 있다.
/// 한 장씩 보는 화면에서는 이것을 번호와 기대 결과로 갈라 보여 준다.
enum StepText {
    struct Broken: Equatable {
        /// 차례대로 하는 일.
        var actions: [String]
        /// 마지막 토막. 눈으로 확인할 결과다.
        var expectation: String?

        var isEmpty: Bool { actions.isEmpty && expectation == nil }
    }

    static func broken(_ steps: String) -> Broken {
        var parts = steps
            .components(separatedBy: "→")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return Broken(actions: [], expectation: nil) }
        // 토막이 하나뿐이면 그것이 곧 확인할 내용이다.
        guard parts.count > 1 else { return Broken(actions: [], expectation: parts[0]) }
        let expectation = parts.removeLast()
        return Broken(actions: parts, expectation: expectation)
    }
}
