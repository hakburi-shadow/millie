import Testing
import Foundation
@testable import Core_Networking

private struct Item: Decodable, Equatable, Sendable {
    let id: String
}

private func makeSUT() -> URLSessionHTTPClient {
    URLSessionHTTPClient(session: .stubbed)
}

private let anyEndpoint = Endpoint(
    baseURL: URL(string: "https://example.com/v1")!,
    path: "items"
)

/// 스텁이 전역 상태라 순차 실행합니다.
@Suite("URLSessionHTTPClient", .serialized)
struct URLSessionHTTPClientTests {

    // MARK: 성공

    @Test("2xx 응답은 디코딩해서 돌려줍니다")
    func success_decodesBody() async throws {
        URLProtocolStub.respond(body: Data(#"[{"id":"ckb"}]"#.utf8))

        let items = try await makeSUT().send(anyEndpoint, as: [Item].self)

        #expect(items == [Item(id: "ckb")])
    }

    @Test("2xx 인데 형식이 다르면 decoding 으로 분류합니다")
    func success_malformedBody_isDecodingError() async {
        URLProtocolStub.respond(body: Data(#"{"unexpected":true}"#.utf8))

        await #expect(throws: NetworkError.self) {
            try await makeSUT().send(anyEndpoint, as: [Item].self)
        }
    }

    // MARK: 호출 제한과 서버 오류

    @Test("429 는 Retry-After 를 초 단위로 읽어 rateLimited 로 분류합니다")
    func rateLimited_parsesIntegerRetryAfter() async {
        URLProtocolStub.respond(status: 429, headers: ["Retry-After": "3"])

        await #expect(throws: NetworkError.rateLimited(retryAfter: 3)) {
            try await makeSUT().send(anyEndpoint, as: [Item].self)
        }
    }

    @Test("Retry-After 가 없으면 대기 시간 없이 rateLimited 입니다")
    func rateLimited_withoutHeader() async {
        URLProtocolStub.respond(status: 429)

        await #expect(throws: NetworkError.rateLimited(retryAfter: nil)) {
            try await makeSUT().send(anyEndpoint, as: [Item].self)
        }
    }

    @Test("5xx 는 서버 사정이므로 재시도 대상입니다")
    func serverError_isRetryable() async throws {
        URLProtocolStub.respond(status: 503)

        let error = await capture { try await makeSUT().send(anyEndpoint, as: [Item].self) }

        #expect(error == .server(status: 503))
        #expect(error?.isRetryable == true)
    }

    @Test("4xx 는 요청이 잘못된 것이므로 재시도하지 않습니다")
    func clientError_isNotRetryable() async {
        URLProtocolStub.respond(status: 404)

        let error = await capture { try await makeSUT().send(anyEndpoint, as: [Item].self) }

        #expect(error == .client(status: 404))
        #expect(error?.isRetryable == false)
    }

    // MARK: 연결 실패 — 저장된 데이터로 넘어갈지 판단하려면 오프라인을 구분해야 합니다

    @Test("연결이 없으면 offline 으로 분류합니다")
    func noConnection_isOffline() async {
        URLProtocolStub.fail(with: .notConnectedToInternet)

        await #expect(throws: NetworkError.offline) {
            try await makeSUT().send(anyEndpoint, as: [Item].self)
        }
    }

    @Test("타임아웃은 offline 과 구분합니다")
    func timeout_isDistinctFromOffline() async {
        URLProtocolStub.fail(with: .timedOut)

        await #expect(throws: NetworkError.timeout) {
            try await makeSUT().send(anyEndpoint, as: [Item].self)
        }
    }
}

@Suite("Retry-After 해석")
struct RetryAfterTests {
    @Test("정수는 초로 읽습니다")
    func integerSeconds() {
        #expect(URLSessionHTTPClient.retryAfterSeconds(from: "120") == 120)
    }

    @Test("HTTP-date 형식도 읽습니다")
    func httpDate() {
        // 기준 시각으로부터 60초 뒤
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let header = "Thu, 14 Nov 2023 22:14:20 GMT" // now + 60s

        let seconds = URLSessionHTTPClient.retryAfterSeconds(from: header, now: now)

        #expect(seconds == 60)
    }

    @Test("해석할 수 없으면 nil 입니다")
    func unparseable() {
        #expect(URLSessionHTTPClient.retryAfterSeconds(from: "곧") == nil)
        #expect(URLSessionHTTPClient.retryAfterSeconds(from: nil) == nil)
    }
}

// MARK: - 도우미

private func capture(_ operation: () async throws -> some Any) async -> NetworkError? {
    do {
        _ = try await operation()
        return nil
    } catch let error as NetworkError {
        return error
    } catch {
        return nil
    }
}
