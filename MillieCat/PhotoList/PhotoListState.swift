import Core_Domain
import Foundation

/// 목록 화면의 상태를 한 덩어리로 담습니다.
///
/// 로딩 여부와 실패 여부를 각각 따로 두면 "로딩 중인데 에러도 표시" 같은
/// 있을 수 없는 조합이 만들어집니다. `phase` 를 열거형 하나로 두면
/// 그런 조합이 타입 차원에서 불가능해집니다.
///
/// 이 타깃은 기본 격리가 `MainActor` 라 선언한 타입이 모두 화면 스레드에 묶입니다.
/// 상태·입력·결과는 값을 나르기만 하고 화면과 무관하므로 격리에서 빼둡니다.
/// 그래야 화면 밖(요청을 수행하는 쪽)에서도 자유롭게 만들고 전달할 수 있습니다.
nonisolated struct PhotoListState: Equatable, Sendable {
    var photos: [Photo] = []
    var phase: Phase = .idle
    /// 지금 보고 있는 것이 저장된 데이터인지, 그렇다면 왜인지 나타냅니다. 안내 문구 노출에 씁니다.
    var source: PhotoSource = .network

    enum Phase: Equatable {
        case idle
        /// 첫 묶음을 불러오는 중입니다. 화면 전체가 비어 있습니다.
        case loading
        /// 이어서 불러오는 중입니다. 이미 보여줄 것이 있습니다.
        case loadingMore
        case loaded
        case failed(AppError)
    }
}

nonisolated extension PhotoListState {
    /// 이미 화면에 있는 id 입니다. 다음 요청에서 제외할 대상으로 넘깁니다.
    var seenIDs: Set<String> {
        Set(photos.map(\.id))
    }

    /// 요청이 이미 진행 중인지 확인합니다.
    ///
    /// 스크롤 이벤트는 짧은 시간에 여러 번 들어오므로, 이 판단이 없으면
    /// 같은 요청이 겹쳐 나갑니다.
    var isLoading: Bool {
        phase == .loading || phase == .loadingMore
    }

    /// 아무것도 보여줄 것이 없는 상태인지 확인합니다.
    var isEmpty: Bool {
        photos.isEmpty
    }

    var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    /// 지금 보고 있는 것이 최신이 아닌 상태인지 확인합니다.
    ///
    /// 저장된 것을 보고 있거나 불러오기에 실패한 경우입니다.
    /// 연결이 돌아왔을 때 다시 불러올지 판단하는 기준이 됩니다.
    var needsFreshData: Bool {
        source.fallbackReason != nil || isFailed
    }
}

/// 화면 밖에서 들어오는 것까지 포함한 입력입니다.
nonisolated enum PhotoListIntent: Equatable, Sendable {
    case onAppear
    /// 목록 끝에 닿았습니다.
    case reachedBottom
    case retry
    /// 끊겼던 연결이 돌아왔습니다.
    case connectionRestored
}

/// 요청의 결과입니다.
nonisolated enum PhotoListEvent: Equatable, Sendable {
    case loadingStarted(isFirstPage: Bool)
    case loaded(PhotoPage)
    case failed(AppError)
}
