import Foundation

/// 실제 서버를 때리지 않고 응답을 지정하기 위한 스텁입니다.
///
/// 네트워크를 타는 테스트는 느리고 결과가 매번 달라집니다. `URLProtocol` 을 갈아 끼우면
/// `URLSession` 코드는 그대로 두고 응답만 바꿀 수 있어, 429·타임아웃처럼
/// **실제로 재현하기 어려운 상황**을 확정적으로 만들 수 있습니다.
final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    struct Stub {
        var statusCode: Int = 200
        var headers: [String: String] = [:]
        var data: Data = Data()
        var error: URLError?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stub: Stub?

    static func set(_ stub: Stub?) {
        lock.lock()
        defer { lock.unlock() }
        Self.stub = stub
    }

    static func respond(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        set(Stub(statusCode: status, headers: headers, data: body))
    }

    static func fail(with code: URLError.Code) {
        set(Stub(error: URLError(code)))
    }

    private static var current: Stub? {
        lock.lock()
        defer { lock.unlock() }
        return stub
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = Self.current else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://stub.invalid")!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    /// 스텁만 태우는 세션입니다.
    static var stubbed: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}
