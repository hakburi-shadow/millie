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

    private func makeSUT(onClose: @escaping () -> Void = {}) -> ImageDetailViewController {
        let photo = Photo(
            id: "abc123",
            url: URL(string: "https://e.com/abc123.jpg")!,
            width: 600,
            height: 400
        )
        let controller = ImageDetailViewController(
            photo: photo,
            loader: StubLoader(bytes: Data()),
            onClose: onClose
        )
        controller.loadViewIfNeeded()
        return controller
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
