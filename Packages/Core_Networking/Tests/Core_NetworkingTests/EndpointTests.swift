import Testing
import Foundation
@testable import Core_Networking

@Suite("Endpoint")
struct EndpointTests {
    @Test("path 와 query 를 붙여 URL 을 만듭니다")
    func makeRequest_buildsURLWithQuery() throws {
        let sut = Endpoint(
            baseURL: URL(string: "https://example.com/v1")!,
            path: "items/search",
            queryItems: [URLQueryItem(name: "limit", value: "10")]
        )

        let request = try sut.makeRequest()

        #expect(request.url?.absoluteString == "https://example.com/v1/items/search?limit=10")
    }

    @Test("query 가 없으면 물음표를 붙이지 않습니다")
    func makeRequest_omitsEmptyQuery() throws {
        let sut = Endpoint(baseURL: URL(string: "https://example.com")!, path: "ping")

        let request = try sut.makeRequest()

        #expect(request.url?.absoluteString == "https://example.com/ping")
    }
}

@Suite("NetworkError")
struct NetworkErrorTests {
    @Test("재시도 대상은 429·5xx·타임아웃뿐입니다")
    func isRetryable_onlyForTransientFailures() {
        #expect(NetworkError.rateLimited(retryAfter: 3).isRetryable)
        #expect(NetworkError.server(status: 503).isRetryable)
        #expect(NetworkError.timeout.isRetryable)

        #expect(!NetworkError.client(status: 404).isRetryable)
        #expect(!NetworkError.offline.isRetryable)
        #expect(!NetworkError.decoding("").isRetryable)
    }
}
