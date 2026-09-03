import Combine
import Core_Domain
import Foundation

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
            guard !state.isLoading else { return }
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
        apply(.loadingStarted(isFirstPage: isFirstPage))

        task?.cancel()
        task = Task { [repository, pageSize, seen = state.seenIDs] in
            let event: PhotoListEvent
            do throws(AppError) {
                event = .loaded(try await repository.loadNext(limit: pageSize, excludingIDs: seen))
            } catch {
                event = .failed(error)
            }

            guard !Task.isCancelled else { return }
            apply(event)
        }
    }

    private func apply(_ event: PhotoListEvent) {
        state = reduce(state, event)
    }
}
