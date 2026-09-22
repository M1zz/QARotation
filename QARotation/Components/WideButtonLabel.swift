import SwiftUI

/// 화면 폭을 꽉 채우는 버튼의 속. 심볼은 왼쪽 끝에 두고 글자는 정중앙에 둔다.
/// 심볼과 글자를 한 덩어리로 가운데 두면 글자가 심볼만큼 오른쪽으로 밀려, 버튼끼리 글자 줄이 안 맞는다.
struct WideButtonLabel: View {
    let title: String
    let systemImage: String
    var minHeight: CGFloat = 44

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            Text(title)
            // 큰 글자에서는 심볼까지 커져 글자와 부딪히므로 글자만 남긴다.
            if !dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}
