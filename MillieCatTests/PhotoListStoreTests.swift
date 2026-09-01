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
}
