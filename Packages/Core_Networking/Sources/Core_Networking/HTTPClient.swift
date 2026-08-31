import Foundation

/// HTTP 통신의 추상입니다. 테스트에서는 `URLProtocol` 스텁을 물린 구현으로 대체합니다.
public protocol HTTPClient: Sendable {
    func send<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: T.Type
    ) async throws(NetworkError) -> T
}
