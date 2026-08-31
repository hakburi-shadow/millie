import Foundation

/// `URLSession` 기반 구현입니다. 외부 네트워크 라이브러리를 쓰지 않았습니다.
///
/// 하는 일은 세 가지뿐입니다 — 요청을 보내고, 상태 코드를 `NetworkError` 로 분류하고, 디코딩합니다.
/// 재시도 정책이나 캐시 판단은 여기 없습니다. 그건 조합 계층의 몫입니다.
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    public func send<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: T.Type
    ) async throws(NetworkError) -> T {
        let request = try endpoint.makeRequest()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.mapTransportFailure(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .transport(.badServerResponse)
        }
        try Self.validate(http)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decoding(String(describing: error))
        }
    }
}

// MARK: - 실패 분류

extension URLSessionHTTPClient {
    /// 연결 단계의 실패를 도메인이 다룰 수 있는 형태로 나눕니다.
    ///
    /// `URLError` 를 통째로 `.transport` 에 넣지 않고 오프라인·타임아웃을 따로 빼는 이유는,
    /// 이 둘이 화면에서 다르게 처리되기 때문입니다 — 오프라인이면 저장된 데이터로 넘어가고,
    /// 타임아웃이면 재시도할 가치가 있습니다.
    static func mapTransportFailure(_ error: some Error) -> NetworkError {
        guard let urlError = error as? URLError else {
            return .transport(.unknown)
        }
        return switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: .offline
        case .timedOut: .timeout
        default: .transport(urlError.code)
        }
    }

    /// 상태 코드를 분류합니다. 429 는 4xx 이지만 재시도 대상이라 따로 뺍니다.
    static func validate(_ response: HTTPURLResponse) throws(NetworkError) {
        switch response.statusCode {
        case 200..<300:
            return
        case 429:
            let header = response.value(forHTTPHeaderField: "Retry-After")
            throw .rateLimited(retryAfter: retryAfterSeconds(from: header))
        case 400..<500:
            throw .client(status: response.statusCode)
        case 500..<600:
            throw .server(status: response.statusCode)
        default:
            throw .transport(.badServerResponse)
        }
    }

    /// `Retry-After` 헤더를 초 단위로 읽습니다.
    ///
    /// 명세상 두 가지 형식이 올 수 있습니다 — 초를 나타내는 정수, 또는 HTTP-date.
    /// 정수만 처리하면 날짜 형식이 왔을 때 조용히 `nil` 이 되어 대기 시간을 잃습니다.
    static func retryAfterSeconds(from header: String?, now: Date = Date()) -> TimeInterval? {
        guard let header = header?.trimmingCharacters(in: .whitespaces), !header.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(header) {
            return max(0, seconds)
        }
        guard let date = httpDateFormatter.date(from: header) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
