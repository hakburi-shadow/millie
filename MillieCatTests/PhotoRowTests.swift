import Core_Domain
import Foundation
import Testing
@testable import MillieCat

@Suite("PhotoRow")
struct PhotoRowTests {

    private func photo(_ id: String) -> Photo {
        Photo(id: id, url: URL(string: "https://example.com/\(id).jpg")!, width: 600, height: 400)
    }

    @Test("줄의 id 는 첫 칸의 id 입니다")
    func id_isFirstPhotoID() {
        let rows = PhotoRow.make(from: ["a", "b", "c"].map(photo), isLandscape: false)

        #expect(rows.map(\.id) == ["a", "b", "c"])
    }

    /// 뒤에 묶음이 붙어도 앞 줄의 id 는 그대로여야 합니다.
    /// 그래야 화면이 앞 줄을 다시 만들지 않고, 받아 둔 이미지도 그대로 남습니다.
    @Test("뒤에 묶음이 붙어도 앞 줄의 id 는 그대로입니다")
    func id_isStableWhenAppending() {
        let first = ["a", "b", "c", "d", "e"].map(photo)
        let appended = first + ["f", "g"].map(photo)

        let before = PhotoRow.make(from: first, isLandscape: true)
        let after = PhotoRow.make(from: appended, isLandscape: true)

        #expect(before.map(\.id) == ["a"])
        #expect(after.map(\.id) == ["a", "f"])
    }
}
