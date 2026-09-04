import Combine
import Testing
import Foundation
import Core_Domain
@testable import MillieCat

private func makePhoto(_ id: String) -> Photo {
    Photo(id: id, url: URL(string: "https://e.com/\(id).jpg")!, width: 300, height: 120)
}

/// 호출 인자와 횟수를 확인할 수 있는 대역입니다.
private actor SpyRepository: PhotoRepository {
    private(set) var callCount = 0
    private(set) var lastExcludingIDs: Set<String> = []
    private var pages: [PhotoPage]
    private let failure: AppError?
    /// 응답을 붙잡아 두어 "요청이 진행 중인" 상태를 만들 때 씁니다.
    private let holds: Bool

    init(pages: [PhotoPage] = [], failure: AppError? = nil, holds: Bool = false) {
        self.pages = pages
        self.failure = failure
        self.holds = holds
    }

    func loadNext(limit: Int, excludingIDs: Set<String>) async throws(AppError) -> PhotoPage {
        callCount += 1
        lastExcludingIDs = excludingIDs

        if holds {
            // 끝나지 않는 요청을 흉내 냅니다.
            try? await Task.sleep(for: .seconds(60))
        }
        if let failure { throw failure }
        return pages.isEmpty ? PhotoPage(photos: [], source: .network) : pages.removeFirst()
    }
}

/// Store 가 상태를 갱신할 때까지 기다립니다.
private func settle() async {
    try? await Task.sleep(for: .milliseconds(50))
}

@MainActor
@Suite("PhotoListStore")
struct PhotoListStoreTests {

    @Test("처음 나타나면 첫 묶음을 불러옵니다")
    func onAppear_loadsFirstPage() async {
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("a")], source: .network)])
        let sut = PhotoListStore(repository: repository)

        sut.send(.onAppear)
        await settle()

        #expect(sut.state.photos.map(\.id) == ["a"])
        #expect(await repository.callCount == 1)
    }

    /// 화면에 다시 나타난 것뿐인데 다시 불러오면 목록이 요동칩니다.
    @Test("이미 불러온 것이 있으면 다시 불러오지 않습니다")
    func onAppear_doesNotReloadWhenAlreadyLoaded() async {
        let repository = SpyRepository()
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded)
        )

        sut.send(.onAppear)
        await settle()

        #expect(await repository.callCount == 0)
    }

    /// 스크롤 이벤트는 짧은 시간에 여러 번 들어옵니다.
    /// 막지 않으면 같은 요청이 겹쳐 나갑니다.
    @Test("요청이 진행 중이면 추가 요청을 보내지 않습니다")
    func reachedBottom_ignoredWhileLoading() async {
        let repository = SpyRepository(holds: true)
        let sut = PhotoListStore(repository: repository)

        sut.send(.onAppear)
        await settle()
        sut.send(.reachedBottom)
        sut.send(.reachedBottom)
        sut.send(.reachedBottom)
        await settle()

        #expect(await repository.callCount == 1)
    }

    @Test("이미 화면에 있는 id 를 제외 대상으로 넘깁니다")
    func reachedBottom_passesSeenIDs() async {
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("c")], source: .network)])
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a"), makePhoto("b")], phase: .loaded)
        )

        sut.send(.reachedBottom)
        await settle()

        #expect(await repository.lastExcludingIDs == ["a", "b"])
    }

    @Test("실패하면 실패 상태로 바뀌고 목록은 남습니다")
    func failure_keepsPhotos() async {
        let repository = SpyRepository(failure: .network)
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded)
        )

        sut.send(.reachedBottom)
        await settle()

        #expect(sut.state.photos.map(\.id) == ["a"])
        #expect(sut.state.phase == .failed(.network))
    }

    @Test("실패한 뒤에는 다시 시도할 수 있습니다")
    func retry_afterFailure() async {
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("a")], source: .network)])
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(phase: .failed(.network))
        )

        sut.send(.retry)
        await settle()

        #expect(sut.state.photos.map(\.id) == ["a"])
        #expect(sut.state.phase == .loaded)
    }

    // MARK: - 이미 본 것만 돌아올 때

    /// 이 API 는 페이지 개념이 없어 이미 본 것만 담긴 묶음이 오기도 합니다.
    /// 그때 목록이 늘지 않으면 화면의 마지막 줄도 그대로라, 다음 요청을 스스로 부르지 못합니다.
    /// 사용자에게는 스크롤 끝에서 아무 반응이 없는 상태로 보입니다.
    @Test("새 항목이 없으면 정해진 횟수만큼 다시 시도합니다")
    func reachedBottom_retriesWhenNothingNewArrives() async {
        // 묶음을 주지 않으면 대역은 매번 빈 결과를 돌려줍니다 — "이미 본 것만 왔다"와 같습니다.
        let repository = SpyRepository()
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded)
        )

        sut.send(.reachedBottom)
        await settle()

        #expect(await repository.callCount == 3)
        #expect(!sut.state.hasMore)
        // 더 없는 것은 실패가 아닙니다. 보고 있던 목록도 그대로여야 합니다.
        #expect(sut.state.phase == .loaded)
        #expect(sut.state.photos.map(\.id) == ["a"])
    }

    /// 끝에 머무는 동안 소득 없는 호출이 반복되면 데이터와 배터리만 씁니다.
    @Test("더 없다고 판단한 뒤에는 요청하지 않습니다")
    func reachedBottom_stopsAfterExhausted() async {
        let repository = SpyRepository()
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded, hasMore: false)
        )

        sut.send(.reachedBottom)
        await settle()

        #expect(await repository.callCount == 0)
    }

    /// 다시 시도하다 새 항목이 나오면 거기서 멈춰야 합니다.
    @Test("새 항목이 나오면 남은 시도를 하지 않습니다")
    func reachedBottom_stopsAsSoonAsSomethingNewArrives() async {
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("b")], source: .network)])
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded)
        )

        sut.send(.reachedBottom)
        await settle()

        #expect(await repository.callCount == 1)
        #expect(sut.state.photos.map(\.id) == ["a", "b"])
        #expect(sut.state.hasMore)
    }
}

/// 연결이 돌아왔을 때의 동작입니다.
///
/// 연결 상태는 값이 몇 번 올지 모르는 흐름이라 Combine 으로 받습니다.
/// 테스트에서는 실제 연결 대신 값을 직접 흘려보내 확인합니다.
@MainActor
@Suite("PhotoListStore 연결 복구")
struct PhotoListStoreConnectivityTests {

    private func cachedState() -> PhotoListState {
        PhotoListState(photos: [makePhoto("a")], phase: .loaded, source: .cache(reason: .offline))
    }

    @Test("저장된 것을 보고 있을 때 연결이 돌아오면 다시 불러옵니다")
    func restored_reloadsWhenShowingCache() async {
        // 연결이 돌아왔으니 새 항목이 오는 상황입니다.
        // 빈 결과를 돌려주면 "이미 본 것만 왔다"가 되어 다시 시도가 섞여 들어옵니다.
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("b")], source: .network)])
        let isOnline = PassthroughSubject<Bool, Never>()
        let sut = PhotoListStore(
            repository: repository,
            initialState: cachedState(),
            isOnline: isOnline.eraseToAnyPublisher()
        )

        isOnline.send(true)
        await settle()

        #expect(await repository.callCount == 1)
        // 다시 불러왔으므로 더 이상 저장된 것을 보고 있지 않습니다.
        #expect(sut.state.source == .network)
        #expect(sut.state.source.fallbackReason == nil)
    }

    /// 잘 보고 있는데 연결 신호만으로 목록을 건드리면 보던 자리를 잃습니다.
    @Test("정상적으로 보고 있으면 연결이 돌아와도 그대로 둡니다")
    func restored_doesNothingWhenAlreadyFresh() async {
        let repository = SpyRepository()
        let isOnline = PassthroughSubject<Bool, Never>()
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(photos: [makePhoto("a")], phase: .loaded, source: .network),
            isOnline: isOnline.eraseToAnyPublisher()
        )

        isOnline.send(true)
        await settle()

        #expect(await repository.callCount == 0)
        #expect(sut.state.photos.map(\.id) == ["a"])
    }

    @Test("연결이 끊겼다는 신호에는 아무것도 하지 않습니다")
    func disconnected_doesNothing() async {
        let repository = SpyRepository()
        let isOnline = PassthroughSubject<Bool, Never>()
        let sut = PhotoListStore(
            repository: repository,
            initialState: cachedState(),
            isOnline: isOnline.eraseToAnyPublisher()
        )

        isOnline.send(false)
        await settle()

        #expect(await repository.callCount == 0)
        #expect(sut.state.source == .cache(reason: .offline))
    }

    @Test("실패한 상태에서 연결이 돌아오면 다시 불러옵니다")
    func restored_reloadsAfterFailure() async {
        let repository = SpyRepository(pages: [PhotoPage(photos: [makePhoto("a")], source: .network)])
        let isOnline = PassthroughSubject<Bool, Never>()
        let sut = PhotoListStore(
            repository: repository,
            initialState: PhotoListState(phase: .failed(.offline)),
            isOnline: isOnline.eraseToAnyPublisher()
        )

        isOnline.send(true)
        await settle()

        #expect(await repository.callCount == 1)
        #expect(!sut.state.isFailed)
        #expect(sut.state.photos.map(\.id) == ["a"])
    }
}
