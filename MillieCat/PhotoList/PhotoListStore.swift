import Combine
import Core_Domain
import Foundation

/// 입력을 받아 필요한 일을 시키고, 결과를 Reducer 에 넘겨 상태를 갱신합니다.
///
/// 상태를 바꾸는 코드는 `reduce` 한 곳뿐이고, 여기서는 무엇을 언제 시킬지만 정합니다.
///
/// `@MainActor` 와 `@Published` 를 쓰는 이유가 있습니다. 상태를 구독하는 쪽이
/// SwiftUI 목록과 UIKit 상세 화면 둘 다인데, `@Published` 는 양쪽 모두에서
/// 같은 방식으로 받아볼 수 있습니다.
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

    init(
        repository: Repository,
        pageSize: Int = 10,
        initialState: PhotoListState = PhotoListState()
    ) {
        self.repository = repository
        self.pageSize = pageSize
        self.state = initialState
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
