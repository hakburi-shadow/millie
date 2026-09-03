import Core_Domain
import Foundation
import Testing
import UIKit
@testable import MillieCat

private struct StubLoader: PhotoDataLoader {
    let bytes: Data

    func data(for url: URL) async throws(AppError) -> Data {
        bytes
    }
}

@MainActor
@Suite("ImageDetailViewController")
struct ImageDetailViewControllerTests {

    private func makeSUT(
        imageData: Data = Data(),
        onClose: @escaping () -> Void = {}
    ) -> ImageDetailViewController {
        let photo = Photo(
            id: "abc123",
            url: URL(string: "https://e.com/abc123.jpg")!,
            width: 600,
            height: 400
        )
        let controller = ImageDetailViewController(
            photo: photo,
            loader: StubLoader(bytes: imageData),
            onClose: onClose
        )
        controller.loadViewIfNeeded()
        return controller
    }

    /// 비율만 확인하면 되므로 내용은 단색으로 채웁니다.
    private func makeImageData(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 이미지를 받아오는 것은 비동기라 잠시 기다립니다.
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("네비게이션 바에 이미지 id 를 표시합니다")
    func title_isPhotoID() {
        #expect(makeSUT().navigationItem.title == "abc123")
    }

    @Test("네비게이션 바에 뒤로가기 버튼이 있습니다")
    func hasBackButton() {
        #expect(makeSUT().navigationItem.leftBarButtonItem != nil)
    }

    /// 뒤로가기는 이 화면이 직접 닫지 않고 띄운 쪽에 알립니다.
    /// 그래야 어디서 띄웠든 닫는 방법을 띄운 쪽이 정할 수 있습니다.
    @Test("뒤로가기를 누르면 닫으라고 알립니다")
    func backButton_notifiesClose() {
        var closed = false
        let sut = makeSUT { closed = true }

        let button = sut.navigationItem.leftBarButtonItem
        _ = button?.target?.perform(button?.action)

        #expect(closed)
    }

    @Test("이미지는 비율을 유지한 채 화면 안에 들어옵니다")
    func imageView_isAspectFit() {
        #expect(makeSUT().imageView.contentMode == .scaleAspectFit)
    }

    @Test("확대는 원래 크기부터 3배까지입니다")
    func zoomScale_isUpToThreeTimes() {
        let sut = makeSUT()

        #expect(sut.scrollView.minimumZoomScale == 1)
        #expect(sut.scrollView.maximumZoomScale == 3)
    }

    /// 설정값이 3이라는 것과 실제로 3에서 멈추는 것은 다른 이야기입니다.
    /// 범위를 벗어난 배율을 넣어 보고 어디서 멈추는지 확인합니다.
    @Test("3배를 넘겨 확대하려 해도 3배에서 멈춥니다")
    func zoom_clampsAtMaximum() {
        let sut = makeSUT()
        sut.view.frame = CGRect(x: 0, y: 0, width: 402, height: 800)
        sut.view.layoutIfNeeded()

        sut.scrollView.zoomScale = 10

        #expect(sut.scrollView.zoomScale == 3)
    }

    @Test("원래 크기보다 작게 축소되지 않습니다")
    func zoom_clampsAtMinimum() {
        let sut = makeSUT()
        sut.view.frame = CGRect(x: 0, y: 0, width: 402, height: 800)
        sut.view.layoutIfNeeded()

        sut.scrollView.zoomScale = 0.1

        #expect(sut.scrollView.zoomScale == 1)
    }

    /// 확대했다가 다시 줄이면 원래대로 돌아와야 합니다.
    @Test("확대한 뒤 축소하면 원래 크기로 돌아옵니다")
    func zoom_returnsToOriginal() {
        let sut = makeSUT()
        sut.view.frame = CGRect(x: 0, y: 0, width: 402, height: 800)
        sut.view.layoutIfNeeded()

        sut.scrollView.zoomScale = 3
        #expect(sut.scrollView.zoomScale == 3)

        sut.scrollView.zoomScale = 1

        #expect(sut.scrollView.zoomScale == 1)
    }

    /// 확대하면 볼 수 있는 영역이 화면보다 커져야 밀어서 다른 곳을 볼 수 있습니다.
    @Test("확대하면 밀어서 볼 수 있는 만큼 넓어집니다")
    func zoom_expandsScrollableArea() {
        let sut = makeSUT()
        sut.view.frame = CGRect(x: 0, y: 0, width: 402, height: 800)
        sut.view.layoutIfNeeded()
        let before = sut.scrollView.contentSize

        sut.scrollView.zoomScale = 3
        sut.view.layoutIfNeeded()

        #expect(sut.scrollView.contentSize.width > before.width)
        #expect(sut.scrollView.contentSize.height > before.height)
    }

    /// 이미지 뷰를 화면 크기로 잡으면 비율을 맞추느라 생긴 여백까지 함께 확대되어,
    /// 확대한 뒤 이미지 바깥의 빈 곳으로 밀려 나갑니다.
    @Test("이미지는 자기 비율만큼만 차지합니다")
    func imageView_matchesImageRatio() async {
        let sut = makeSUT(imageData: makeImageData(width: 100, height: 50))
        sut.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        sut.view.layoutIfNeeded()

        await settle()

        // 가로 2 : 세로 1 이므로 폭 400 에 맞추면 높이는 200 입니다.
        #expect(sut.imageView.frame.width == 400)
        #expect(sut.imageView.frame.height == 200)
        #expect(sut.imageView.frame.height < sut.scrollView.bounds.height)
    }

    @Test("화면보다 작은 이미지는 가운데에 옵니다")
    func imageView_isCentered() async {
        let sut = makeSUT(imageData: makeImageData(width: 100, height: 50))
        sut.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        sut.view.layoutIfNeeded()

        await settle()

        // 위아래로 남는 600 이 절반씩 나뉩니다.
        #expect(sut.scrollView.contentInset.top == 300)
        #expect(sut.scrollView.contentInset.bottom == 300)
        #expect(sut.scrollView.contentInset.left == 0)
    }

    @Test("확대 대상은 이미지입니다")
    func viewForZooming_isImageView() {
        let sut = makeSUT()

        #expect(sut.scrollView.delegate?.viewForZooming?(in: sut.scrollView) === sut.imageView)
    }

    /// 화면 크기가 바뀌면 확대를 풀고 다시 맞춥니다.
    /// 회전 전의 배율과 위치를 그대로 두면 엉뚱한 곳을 보게 됩니다.
    @Test("화면 크기가 바뀌면 확대가 풀립니다")
    func zoom_resetsWhenSizeChanges() {
        let sut = makeSUT()
        sut.view.frame = CGRect(x: 0, y: 0, width: 402, height: 800)
        sut.view.layoutIfNeeded()

        sut.scrollView.zoomScale = 3
        sut.view.frame = CGRect(x: 0, y: 0, width: 800, height: 402)
        sut.view.layoutIfNeeded()

        #expect(sut.scrollView.zoomScale == 1)
        #expect(sut.imageView.frame.size == sut.scrollView.bounds.size)
    }
}
