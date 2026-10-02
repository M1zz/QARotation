import SwiftUI

extension View {
    /// 아이패드처럼 넓은 화면에서 글줄과 버튼이 끝없이 늘어나지 않게 가운데 기둥에 모은다.
    /// 아이폰은 기둥보다 좁으므로 아무것도 바뀌지 않는다. 배경은 이 뒤에 붙여야 화면 끝까지 깔린다.
    func readableColumn(_ maxWidth: CGFloat = 720, alignment: Alignment = .center) -> some View {
        frame(maxWidth: maxWidth, alignment: alignment)
            .frame(maxWidth: .infinity)
    }
}
