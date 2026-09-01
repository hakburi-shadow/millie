import CoreGraphics

/// 화면 방향에 따른 격자 규격입니다.
///
/// 화면 코드 안에 숫자를 흩어 놓지 않고 여기로 모았습니다.
/// 순수 함수라 화면을 띄우지 않고도 규격이 맞는지 확인할 수 있습니다.
nonisolated enum GridLayoutSpec {
    static let spacing: CGFloat = 8

    /// 가로일 때의 칸 크기입니다. 과제에서 지정한 값입니다.
    static let landscapeCellSize = CGSize(width: 300, height: 120)

    /// 세로일 때의 칸 높이입니다. 너비는 화면을 꽉 채웁니다.
    static let portraitCellHeight: CGFloat = 240

    static func columnCount(isLandscape: Bool) -> Int {
        isLandscape ? 5 : 1
    }

    static func cellSize(isLandscape: Bool, containerWidth: CGFloat) -> CGSize {
        guard isLandscape else {
            return CGSize(width: containerWidth, height: portraitCellHeight)
        }
        return landscapeCellSize
    }

    /// 격자 전체의 너비입니다.
    ///
    /// 가로일 때 5칸 × 300 은 어떤 아이폰의 가로 폭보다도 넓습니다.
    /// 그래서 화면 폭에 맞추지 않고 이 값을 그대로 써서 좌우로도 스크롤되게 합니다.
    static func contentWidth(isLandscape: Bool, containerWidth: CGFloat) -> CGFloat {
        guard isLandscape else { return containerWidth }
        let columns = CGFloat(columnCount(isLandscape: true))
        return columns * landscapeCellSize.width + (columns - 1) * spacing
    }

    /// 화면이 가로인지 판단합니다.
    ///
    /// 기기 방향(`UIDevice.orientation`)이 아니라 실제로 그릴 크기로 판단합니다.
    /// 기기 방향에는 화면을 위로 둔 상태처럼 가로도 세로도 아닌 값이 섞여 들어옵니다.
    static func isLandscape(containerSize: CGSize) -> Bool {
        containerSize.width > containerSize.height
    }
}
