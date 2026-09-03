import Combine
import Foundation
import Testing
@testable import Core_Networking

@Suite("ConnectivityMonitor")
struct ConnectivityMonitorTests {

    /// 구독하는 시점이 시스템의 첫 알림보다 늦을 수 있습니다.
    /// 그때 아무 값도 받지 못하면 화면은 연결 상태를 영영 모르게 됩니다.
    @Test("구독하면 현재 상태부터 받습니다")
    func emitsCurrentStateOnSubscribe() async {
        let monitor = ConnectivityMonitor()

        let received: Bool? = await withCheckedContinuation { continuation in
            var token: AnyCancellable?
            var resumed = false

            token = monitor.isOnline.sink { value in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
                token?.cancel()
            }
        }

        #expect(received != nil)
    }
}
