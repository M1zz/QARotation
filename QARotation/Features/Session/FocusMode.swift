import Foundation

/// 어떤 앱을 한 장씩 보기로 열 것인가.
/// 항목이 많고 단계가 긴 앱부터 넣는다. 우선 클립키보드로 써 보고 늘린다.
enum FocusMode {
    static let bundleIDs: Set<String> = ["com.ysoup.tokenmemo"]

    static func opensFocused(bundleID: String) -> Bool {
        bundleIDs.contains(bundleID.trimmingCharacters(in: .whitespaces).lowercased())
    }
}
