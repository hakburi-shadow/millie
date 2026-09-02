import Testing
import CoreGraphics
@testable import MillieCat

@Suite("GridLayoutSpec")
struct GridLayoutSpecTests {

    @Test("세로는 한 칸, 가로는 다섯 칸입니다")
    func columnCount() {
        #expect(GridLayoutSpec.columnCount(isLandscape: false) == 1)
        #expect(GridLayoutSpec.columnCount(isLandscape: true) == 5)
    }

    @Test("세로에서는 칸이 화면 폭을 채웁니다")
    func cellSize_portraitFillsWidth() {
        let size = GridLayoutSpec.cellSize(isLandscape: false, containerWidth: 402)

        #expect(size.width == 402)
    }

    @Test("가로에서는 칸이 300 × 120 입니다")
    func cellSize_landscapeIsFixed() {
        let size = GridLayoutSpec.cellSize(isLandscape: true, containerWidth: 874)

        #expect(size == CGSize(width: 300, height: 120))
    }

    /// 5칸 × 300 은 어떤 아이폰의 가로 폭보다도 넓습니다.
    /// 줄을 화면 폭에 맞추지 않아야 그 줄이 좌우로 넘어갑니다.
    @Test("가로에서 한 줄의 너비가 화면 폭을 넘습니다")
    func rowWidth_landscapeExceedsScreen() {
        let screenWidth: CGFloat = 874
        let width = GridLayoutSpec.rowWidth(isLandscape: true, containerWidth: screenWidth)

        #expect(width == 5 * 300 + 4 * GridLayoutSpec.spacing)
        #expect(width > screenWidth)
    }

    @Test("세로에서는 한 줄이 화면 폭에 맞습니다")
    func rowWidth_portraitMatchesScreen() {
        #expect(GridLayoutSpec.rowWidth(isLandscape: false, containerWidth: 402) == 402)
    }

    @Test("가로에서는 다섯 칸씩 끊습니다")
    func rows_landscapeChunksByFive() {
        let rows = GridLayoutSpec.rows(Array(1 ... 12), isLandscape: true)

        #expect(rows == [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10], [11, 12]])
    }

    @Test("세로에서는 한 칸씩 끊습니다")
    func rows_portraitChunksByOne() {
        #expect(GridLayoutSpec.rows([1, 2, 3], isLandscape: false) == [[1], [2], [3]])
    }

    @Test("비어 있으면 줄도 없습니다")
    func rows_empty() {
        #expect(GridLayoutSpec.rows([Int](), isLandscape: true).isEmpty)
    }

    /// 기기 방향에는 화면을 위로 둔 상태처럼 가로도 세로도 아닌 값이 섞여 들어옵니다.
    /// 그래서 실제로 그릴 크기로 판단합니다.
    @Test("그릴 크기로 방향을 판단합니다")
    func isLandscape_usesContainerSize() {
        #expect(GridLayoutSpec.isLandscape(containerSize: CGSize(width: 874, height: 402)))
        #expect(!GridLayoutSpec.isLandscape(containerSize: CGSize(width: 402, height: 874)))
    }
}
