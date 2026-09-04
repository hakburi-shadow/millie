import Combine
import Core_Domain
import Foundation

/// 한 번의 불러오기에서 요청을 보낼 수 있는 최대 횟수입니다.
///
/// 이 API 는 페이지 개념이 없어 매번 무작위 묶음을 돌려주고, 이미 본 것만 담겨 오기도 합니다.
/// 그러면 목록이 늘지 않고, 화면의 마지막 줄도 그대로라 다음 요청을 스스로 부르지 못한 채
/// 멈춥니다. 사용자가 보기에는 스크롤이 끝에서 아무 반응이 없는 상태입니다.
///
/// 그래서 새 항목이 나올 때까지 몇 번 더 시도합니다. 무한히 시도하지는 않습니다 —
/// 정말로 더 없을 때 요청만 반복하게 되기 때문입니다. 정해진 횟수 안에 새 항목이 없으면
/// 더 없는 것으로 보고(`PhotoListState.hasMore`) 멈춥니다.
///
/// `PhotoListStore` 가 제네릭이라 타입 안에 둘 수 없어(제네릭 타입은 저장 static 프로퍼티를
/// 가질 수 없습니다) 파일 수준에 두었습니다.
private let maxAttemptsPerLoad = 3

/// 입력을 받아 필요한 일을 시키고, 결과를 Reducer 에 넘겨 상태를 갱신합니다.
///
/// 상태를 바꾸는 코드는 `reduce` 한 곳뿐이고, 여기서는 무엇을 언제 시킬지만 정합니다.
///
/// 비동기를 두 가지 방식으로 나눠 씁니다.
///
/// - **요청 한 번에 결과 한 번**인 일(`loadNext`)은 Swift Concurrency 로 처리합니다.
///   시작과 끝이 있고 위에서 아래로 읽힙니다.
/// - **끝없이 흘러오는 것**(연결이 끊기고 붙는 것, 상태가 바뀌었다는 알림)은 Combine 으로
///   다룹니다. 값이 몇 번 올지 모르는 일은 `await` 로 표현되지 않습니다.
///
/// 저장소를 `any PhotoRepository` 가 아니라 제네릭으로 받는 이유가 있습니다.
/// 존재 타입을 거쳐 호출하면 `throws(AppError)` 가 `any Error` 로 지워져,
/// 어떤 실패가 오는지 알고 처리하려던 이점이 사라집니다.
@MainActor
final class PhotoListStore<Repository: PhotoRepository>: ObservableObject {
    @Published private(set) var state: PhotoListState

    private let repository: Repository
    private let pageSize: Int
    private var task: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// 연결 상태는 구현체가 아니라 흐름 그 자체로 받습니다.
    /// 이 계층에 필요한 것은 "연결이 어떻게 바뀌는가" 뿐이라,
    /// 무엇이 그것을 알려주는지는 알 필요가 없습니다.
    init(
        repository: Repository,
        pageSize: Int = 10,
        initialState: PhotoListState = PhotoListState(),
        isOnline: AnyPublisher<Bool, Never>? = nil
    ) {
        self.repository = repository
        self.pageSize = pageSize
        self.state = initialState

        if let isOnline {
            observe(isOnline)
        }
    }

    private func observe(_ isOnline: AnyPublisher<Bool, Never>) {
        isOnline
            // 끊긴 순간이 아니라 돌아온 순간만 봅니다.
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor in self?.send(.connectionRestored) }
            }
            .store(in: &cancellables)
    }

    func send(_ intent: PhotoListIntent) {
        switch intent {
        case .onAppear:
            // 이미 불러온 것이 있으면 화면에 다시 나타난 것뿐이므로 아무것도 하지 않습니다.
            guard state.isEmpty, !state.isLoading else { return }
            load(isFirstPage: true)

        case .reachedBottom:
            // 스크롤 이벤트는 짧은 시간에 여러 번 들어옵니다.
            // 진행 중인 요청이 있으면 무시해 같은 요청이 겹쳐 나가지 않게 합니다.
            //
            // 더 없다고 판단된 뒤에는 요청하지 않습니다. 끝에 머무는 동안 소득 없는 호출이
            // 반복되고, 사용자에게는 아무 일도 일어나지 않는 것으로 보이기 때문입니다.
            guard !state.isLoading, state.hasMore else { return }
            load(isFirstPage: false)

        case .retry:
            guard !state.isLoading else { return }
            load(isFirstPage: state.isEmpty)

        case .connectionRestored:
            // 저장된 것을 보고 있거나 실패한 상태일 때만 다시 불러옵니다.
            // 잘 보고 있는데 연결 신호만으로 목록을 건드리면 보던 자리를 잃습니다.
            guard !state.isLoading, state.needsFreshData else { return }
            load(isFirstPage: state.isEmpty)
        }
    }

    private func load(isFirstPage: Bool) {
        task?.cancel()
        task = Task { [pageSize] in
            for _ in 1 ... maxAttemptsPerLoad {
                // 시도할 때마다 다시 표시합니다. 그래야 다시 시도하는 동안에도 `isLoading` 이
                // 참으로 유지되어, 겹쳐 들어오는 스크롤 이벤트가 요청을 새로 만들지 않습니다.
                apply(.loadingStarted(isFirstPage: isFirstPage))
                let countBefore = state.photos.count

                let event: PhotoListEvent
                do throws(AppError) {
                    event = .loaded(
                        try await repository.loadNext(limit: pageSize, excludingIDs: state.seenIDs)
                    )
                } catch {
                    event = .failed(error)
                }

                guard !Task.isCancelled else { return }
                apply(event)

                // 새로 붙은 것이 있거나 실패했으면 여기서 끝냅니다.
                // 남는 경우는 "이미 본 것만 돌아온" 때뿐이라, 그때만 다시 시도합니다.
                guard state.photos.count == countBefore, !state.isFailed else { return }
            }
        }
    }

    private func apply(_ event: PhotoListEvent) {
        state = reduce(state, event)
    }
}
