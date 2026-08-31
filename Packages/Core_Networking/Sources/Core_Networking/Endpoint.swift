import Foundation

/// 요청을 서술하는 값 타입입니다. 값이라서 테스트에서 그대로 비교할 수 있습니다.
///
/// **이 타입은 특정 API 를 모릅니다.** TheCatAPI 의 실제 주소와 파라미터는 `Core_Service` 에
/// 있습니다. 이 모듈은 "어떻게 보내는가"만 알고, "어디로 무엇을 보내는가"는 조합 계층의 몫입니다.
public struct Endpoint: Equatable, Sendable {
    public let baseURL: URL
    public let path: String
    public let queryItems: [URLQueryItem]

    public init(baseURL: URL, path: String, queryItems: [URLQueryItem] = []) {
        self.baseURL = baseURL
        self.path = path
        self.queryItems = queryItems
    }

    public func makeRequest() throws(NetworkError) -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw .invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw .invalidURL }
        return URLRequest(url: url)
    }
}
