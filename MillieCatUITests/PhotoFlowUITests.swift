import XCTest

/// 목록에서 상세까지 실제로 눌러 보는 테스트입니다.
///
/// 단위 테스트는 "신호를 받으면 무엇을 하는가"까지만 답합니다.
/// 눌렀을 때 실제로 그 화면이 열리는지는 앱을 띄워 눌러 봐야 알 수 있습니다.
///
/// 앱과 다른 프로세스에서 돌기 때문에 앱의 타입을 가져다 쓸 수 없어,
/// 화면 요소 이름을 여기에 같은 값으로 적어 둡니다.
/// 앱 쪽 `AccessibilityID` 를 고치면 여기도 함께 고쳐야 합니다.
private enum ID {
    static let photoCell = "photoCell"
    static let detailImage = "detailImage"
    static let detailBackButton = "detailBackButton"
}

/// 실제 서버에서 목록을 받아오므로 첫 화면은 넉넉히 기다립니다.
private let listTimeout: TimeInterval = 20
private let transitionTimeout: TimeInterval = 5

final class PhotoFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // 이전 테스트가 돌려 둔 방향이 남지 않도록 매번 세로에서 시작합니다.
        XCUIDevice.shared.orientation = .portrait

        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        app = nil
        super.tearDown()
    }

    private func firstCell() -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: ID.photoCell).firstMatch
    }

    func test_목록에_이미지가_표시된다() {
        XCTAssertTrue(
            firstCell().waitForExistence(timeout: listTimeout),
            "목록에 칸이 하나도 나타나지 않았습니다"
        )
    }

    func test_칸을_누르면_상세가_열리고_뒤로_누르면_닫힌다() {
        let cell = firstCell()
        XCTAssertTrue(cell.waitForExistence(timeout: listTimeout))

        cell.tap()

        let detailImage = app.images[ID.detailImage]
        let backButton = app.buttons[ID.detailBackButton]
        XCTAssertTrue(
            detailImage.waitForExistence(timeout: transitionTimeout),
            "상세 화면이 열리지 않았습니다"
        )
        XCTAssertTrue(backButton.exists, "뒤로가기 버튼이 없습니다")
        XCTAssertTrue(app.navigationBars.firstMatch.exists, "네비게이션 바가 없습니다")

        backButton.tap()

        XCTAssertTrue(
            detailImage.waitForNonExistence(timeout: transitionTimeout),
            "뒤로가기를 눌렀는데 상세 화면이 닫히지 않았습니다"
        )
        XCTAssertTrue(firstCell().waitForExistence(timeout: transitionTimeout))
    }

    /// 가로에서는 한 줄에 다섯 칸이 들어가고 줄마다 좌우로 넘어갑니다.
    /// 화면 폭보다 줄이 넓어서, 처음에는 일부 칸만 보입니다.
    func test_가로로_돌려도_목록이_보인다() {
        XCTAssertTrue(firstCell().waitForExistence(timeout: listTimeout))

        XCUIDevice.shared.orientation = .landscapeLeft

        XCTAssertTrue(
            firstCell().waitForExistence(timeout: transitionTimeout),
            "가로로 돌린 뒤 목록이 사라졌습니다"
        )
    }
}
