import Testing
import Foundation
import Core_Domain
@testable import MillieCat

private func makePhoto(_ id: String) -> Photo {
    Photo(id: id, url: URL(string: "https://e.com/\(id).jpg")!, width: 300, height: 120)
}

private func page(_ ids: [String], source: PhotoSource = .network) -> PhotoPage {
    PhotoPage(photos: ids.map(makePhoto), source: source)
}

@Suite("PhotoListReducer")
struct PhotoListReducerTests {

    @Test("받은 것을 목록에 이어붙입니다")
    func loaded_appendsPhotos() {
        let state = PhotoListState(photos: [makePhoto("a")])

        let next = reduce(state, .loaded(page(["b", "c"])))

        #expect(next.photos.map(\.id) == ["a", "b", "c"])
        #expect(next.phase == .loaded)
    }

    /// 이 API 는 같은 id 를 반복해서 돌려줍니다.
    /// 걸러내지 않으면 같은 이미지가 여러 번 나오고 화면을 그릴 때도 id 가 겹칩니다.
    @Test("이미 있는 id 는 건너뜁니다")
    func loaded_skipsDuplicates() {
        let state = PhotoListState(photos: [makePhoto("a"), makePhoto("b")])

        let next = reduce(state, .loaded(page(["b", "c", "a", "d"])))

        #expect(next.photos.map(\.id) == ["a", "b", "c", "d"])
    }

    @Test("한 번에 들어온 묶음 안의 중복도 걸러냅니다")
    func loaded_skipsDuplicatesWithinSameBatch() {
        let next = reduce(PhotoListState(), .loaded(page(["a", "a", "b"])))

        #expect(next.photos.map(\.id) == ["a", "b"])
    }

    /// 이어서 불러오다 실패했다고 보고 있던 것을 지우면
    /// 사용자는 화면이 초기화된 것으로 받아들입니다.
    @Test("실패해도 이미 보고 있던 목록은 남깁니다")
    func failed_keepsExistingPhotos() {
        let state = PhotoListState(photos: [makePhoto("a")], phase: .loadingMore)

        let next = reduce(state, .failed(.network))

        #expect(next.photos.map(\.id) == ["a"])
        #expect(next.phase == .failed(.network))
    }

    /// 저장된 데이터를 보고 있다는 사실을 화면이 알아야 안내를 띄울 수 있습니다.
    @Test("어디서 온 것인지 상태에 남깁니다")
    func loaded_recordsSource() {
        let next = reduce(PhotoListState(), .loaded(page(["a"], source: .cache)))

        #expect(next.source == .cache)
    }

    @Test("첫 묶음과 이어서 불러오기를 구분합니다")
    func loadingStarted_distinguishesFirstPage() {
        #expect(reduce(PhotoListState(), .loadingStarted(isFirstPage: true)).phase == .loading)
        #expect(reduce(PhotoListState(), .loadingStarted(isFirstPage: false)).phase == .loadingMore)
    }

    @Test("이미 화면에 있는 id 를 다음 요청의 제외 대상으로 넘깁니다")
    func seenIDs_collectsCurrentPhotos() {
        let state = PhotoListState(photos: [makePhoto("a"), makePhoto("b")])

        #expect(state.seenIDs == ["a", "b"])
    }
}
