import Core_Domain
import Foundation

/// 상태를 바꾸는 유일한 곳입니다.
///
/// 순수 함수라 화면도 네트워크도 없이 그대로 호출해 확인할 수 있습니다.
nonisolated func reduce(_ state: PhotoListState, _ event: PhotoListEvent) -> PhotoListState {
    var next = state

    switch event {
    case .loadingStarted(let isFirstPage):
        next.phase = isFirstPage ? .loading : .loadingMore

    case .loaded(let page):
        next.photos = appendingWithoutDuplicates(page.photos, to: state.photos)
        next.source = page.source
        next.phase = .loaded

    case .failed(let error):
        next.phase = .failed(error)
        // 목록은 그대로 둡니다. 이어서 불러오다 실패했다고 보고 있던 것을 지우면
        // 사용자는 화면이 초기화된 것으로 받아들입니다.
    }

    return next
}

/// 이미 있는 id 는 건너뛰고 이어붙입니다.
///
/// 이 API 는 같은 id 를 반복해서 돌려주므로 이 처리가 없으면 같은 이미지가 여러 번 나오고,
/// 화면을 그리는 쪽에서도 id 가 겹쳐 문제가 됩니다.
nonisolated private func appendingWithoutDuplicates(_ incoming: [Photo], to existing: [Photo]) -> [Photo] {
    var seen = Set(existing.map(\.id))
    var result = existing

    for photo in incoming where seen.insert(photo.id).inserted {
        result.append(photo)
    }
    return result
}
