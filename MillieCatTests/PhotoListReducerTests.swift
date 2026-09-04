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

    /// 저장된 데이터를 보고 있다는 사실과 **그 원인**을 화면이 알아야
    /// 연결 없음과 호출 제한을 구분해 안내할 수 있습니다.
    @Test("어디서 온 것인지 원인까지 상태에 남깁니다")
    func loaded_recordsSourceWithReason() {
        let next = reduce(
            PhotoListState(),
            .loaded(page(["a"], source: .cache(reason: .rateLimited(retryAfter: 30))))
        )

        #expect(next.source == .cache(reason: .rateLimited(retryAfter: 30)))
        #expect(next.source.fallbackReason == .rateLimited(retryAfter: 30))
    }

    @Test("첫 묶음과 이어서 불러오기를 구분합니다")
    func loadingStarted_distinguishesFirstPage() {
        #expect(reduce(PhotoListState(), .loadingStarted(isFirstPage: true)).phase == .loading)
        #expect(reduce(PhotoListState(), .loadingStarted(isFirstPage: false)).phase == .loadingMore)
    }

    // MARK: - 더 불러올 것이 남았는지

    @Test("새로 붙은 것이 있으면 더 있다고 봅니다")
    func loaded_withNewPhotos_keepsHasMore() {
        let state = PhotoListState(photos: [makePhoto("a")])

        let next = reduce(state, .loaded(page(["b"])))

        #expect(next.hasMore)
    }

    /// 이 API 에는 "마지막 페이지" 신호가 없어서, 끝은 응답이 아니라 결과로 판단합니다.
    @Test("이미 본 것만 돌아오면 더 없다고 봅니다")
    func loaded_withOnlyDuplicates_clearsHasMore() {
        let state = PhotoListState(photos: [makePhoto("a"), makePhoto("b")])

        let next = reduce(state, .loaded(page(["a", "b"])))

        #expect(!next.hasMore)
    }

    @Test("빈 묶음이 오면 더 없다고 봅니다")
    func loaded_withEmptyPage_clearsHasMore() {
        let state = PhotoListState(photos: [makePhoto("a")])

        let next = reduce(state, .loaded(page([])))

        #expect(!next.hasMore)
        // 더 없다는 것과 실패는 다릅니다. 보고 있던 목록은 그대로여야 합니다.
        #expect(next.phase == .loaded)
        #expect(next.photos.map(\.id) == ["a"])
    }

    /// 그대로 두면 한 번 끝에 닿은 뒤로는 새로 고쳐도 이어서 불러올 수 없습니다.
    @Test("처음부터 다시 불러오면 더 없음 판단도 되돌립니다")
    func loadingStarted_firstPage_resetsHasMore() {
        let state = PhotoListState(photos: [makePhoto("a")], hasMore: false)

        #expect(reduce(state, .loadingStarted(isFirstPage: true)).hasMore)
        // 이어서 불러오는 중에는 되돌리지 않습니다. 방금 내린 판단을 지우게 됩니다.
        #expect(!reduce(state, .loadingStarted(isFirstPage: false)).hasMore)
    }

    @Test("이미 화면에 있는 id 를 다음 요청의 제외 대상으로 넘깁니다")
    func seenIDs_collectsCurrentPhotos() {
        let state = PhotoListState(photos: [makePhoto("a"), makePhoto("b")])

        #expect(state.seenIDs == ["a", "b"])
    }
}
