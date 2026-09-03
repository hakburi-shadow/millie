import Combine
import Foundation
import Network

/// 연결이 끊기고 붙는 것을 값으로 흘려보냅니다.
///
/// 요청 한 번의 성공·실패와는 성격이 다릅니다. 끝이 없고, 언제 몇 번 바뀔지 모릅니다.
/// `await` 로는 "다음 변화 하나를 기다린다"까지만 표현되므로,
/// 값이 올 때마다 반응하는 통로를 미리 만들어 두는 방식을 씁니다.
public final class ConnectivityMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.millie.cat.connectivity")

    /// 마지막 상태를 들고 있어서 늦게 구독한 쪽도 현재 상태부터 받습니다.
    private let state: CurrentValueSubject<Bool, Never>

    /// 연결되어 있으면 `true` 입니다. 바뀔 때만 값이 흐릅니다.
    public var isOnline: AnyPublisher<Bool, Never> {
        state.removeDuplicates().eraseToAnyPublisher()
    }

    /// 처음에는 연결된 것으로 둡니다.
    ///
    /// 시스템이 첫 경로를 알려주기 전에 끊긴 것으로 단정하면, 실제로는 멀쩡한데도
    /// 저장된 데이터를 보여주는 쪽으로 잠깐 기울게 됩니다.
    public init() {
        state = CurrentValueSubject(true)

        let box = SendableBox(wrapped: state)
        monitor.pathUpdateHandler = { path in
            box.wrapped.send(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

/// Combine 의 `Subject` 는 Swift 6 이전에 만들어져 다른 스레드로 넘겨도 되는 타입으로
/// 표시돼 있지 않습니다. 그래서 감시 함수 안으로 그냥 넘기면 컴파일이 막힙니다.
///
/// 여기서는 값을 보내는 곳이 위의 직렬 큐 하나뿐이라 동시에 보내는 일이 없습니다.
/// 그 사실을 컴파일러에 알려 주기 위한 최소한의 포장입니다.
private struct SendableBox<Value>: @unchecked Sendable {
    let wrapped: Value
}
