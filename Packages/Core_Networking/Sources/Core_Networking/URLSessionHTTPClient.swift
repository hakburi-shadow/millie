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

// MARK: - 바이너리 내려받기

extension URLSessionHTTPClient: DataDownloader {
    public func data(from url: URL) async throws(NetworkError) -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw Self.mapTransportFailure(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw .transport(.badServerResponse)
        }
        try Self.validate(http)
        return data
    }
}

// MARK: - 실패 분류

extension URLSessionHTTPClient {
    /// 연결 단계의 실패를 도메인이 다룰 수 있는 형태로 나눕니다.
    ///
    /// `URLError` 를 통째로 `.transport` 에 넣지 않고 오프라인·타임아웃을 따로 빼는 이유는,
    /// 이 둘이 화면에서 다르게 처리되기 때문입니다 — 오프라인이면 저장된 데이터로 넘어가고,
    /// 타임아웃이면 재시도할 가치가 있습니다.
    ///
    /// 어느 코드가 어느 상황에 오는지는 `URLError` 문서에 따른 것이고,
    /// 실제로 연결을 끊어 확인하지는 못했습니다. 스텁으로만 고정해 두었습니다.
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
    /// RFC 9110 §10.2.3 이 두 가지 형식을 허용합니다 — 초를 나타내는 정수(delay-seconds),
    /// 또는 HTTP-date. 정수만 처리하면 날짜 형식이 왔을 때 조용히 `nil` 이 되어 대기 시간을 잃습니다.
    ///
    /// 다만 이 헤더는 **선택(MAY)** 이라 429 라도 없을 수 있고, 없으면 `nil` 을 돌려줍니다.
    /// 화면은 그때 대기 시간 없는 안내로 갈립니다.
    ///
    /// **이 API 가 실제로 429 를 보내는지, 보낸다면 이 헤더를 붙이는지는 확인하지 못했습니다.**
    /// 정상 응답에는 제한 관련 헤더가 하나도 없어서 정책을 짐작할 근거도 없었습니다.
    /// 그래서 이 처리는 관찰이 아니라 명세에 근거한 방어입니다.
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
