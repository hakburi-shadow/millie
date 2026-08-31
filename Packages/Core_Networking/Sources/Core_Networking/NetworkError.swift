import Foundation

/// 전송 계층의 실패 표현입니다.
///
/// 호출 제한이 걸릴 수 있는 API 이므로 `rateLimited` 를 별도 case 로 둡니다.
/// 재시도해서 해결될 수 있는지를 타입 수준에서 나눠, 429·5xx·타임아웃만 재시도하고
/// 4xx 는 즉시 포기합니다.
public enum NetworkError: Error, Equatable, Sendable {
    /// 네트워크 연결 자체가 없습니다.
    case offline
    case timeout
    /// 429. `retryAfter` 는 `Retry-After` 헤더에서 읽은 대기 시간(초)입니다.
    case rateLimited(retryAfter: TimeInterval?)
    /// 5xx — 서버 사정이므로 잠시 후 다시 시도할 가치가 있습니다.
    case server(status: Int)
    /// 4xx (429 제외) — 요청 자체가 잘못됐으므로 재시도해도 같은 결과입니다.
    case client(status: Int)
    case decoding(String)
    case transport(URLError.Code)
    case invalidURL
}

public extension NetworkError {
    /// 같은 요청을 다시 보내서 해결될 수 있는 실패인지 판단합니다.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .server, .timeout: true
        case .offline, .client, .decoding, .transport, .invalidURL: false
        }
    }
}
