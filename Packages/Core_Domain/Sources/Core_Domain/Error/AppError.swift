import Foundation

/// 화면이 이해하는 최종 실패 표현입니다.
///
/// 네트워크와 저장소의 구체적인 에러 타입은 각 모듈 안에 갇혀 있고, Repository 경계에서
/// 이 타입으로 번역됩니다.
///
/// **표시 문구는 여기 두지 않습니다.** 사용자에게 보일 문장은 언어·톤·플랫폼에 따라 달라지는
/// 화면 관심사이고, 도메인이 그것을 알면 이 모듈이 UI 에 묶입니다.
/// 문구 매핑은 앱 타깃의 `AppError+Message.swift` 가 담당합니다.
public enum AppError: Error, Equatable, Sendable {
    /// 연결이 없습니다.
    ///
    /// **"보여줄 것이 있는가"는 이 타입이 답하지 않습니다.** 오프라인이어도 저장된 것이 있으면
    /// 화면은 정상이고, 없으면 빈 화면입니다. 그 구분은 상태(`photos` 가 비었는지)가 이미 알고 있어서
    /// 여기에 함께 담으면 같은 사실이 두 곳에 생기고, 두 곳이 어긋날 수 있습니다.
    ///
    /// 실제로 어긋났습니다. 이전 이름은 `offlineAndEmpty` 였는데, 오프라인에서 이어서 불러오다
    /// 저장분이 떨어졌을 때도 이 값이 나오면서 이미지가 가득한 화면에 "저장된 것도 없다"는
    /// 안내가 붙었습니다. 이름이 약속한 것을 코드가 지키지 못한 것이라 이름 쪽을 좁혔습니다.
    case offline
    /// API 호출 제한입니다. `retryAfter` 는 서버가 알려준 대기 시간(초)입니다.
    case rateLimited(retryAfter: TimeInterval?)
    /// 그 밖의 네트워크 실패입니다. 캐시가 있으면 그쪽으로 넘어가므로 치명적이지 않습니다.
    case network
    /// 로컬 저장소 실패입니다.
    case storage
    /// 응답 형식이 예상과 다릅니다.
    case decoding
}

public extension AppError {
    /// 같은 요청을 다시 시도해서 해결될 수 있는 실패인지 판단합니다.
    ///
    /// 재시도 버튼을 실제로 그릴지는 화면이 정하지만, **일시적 실패(연결·혼잡)와
    /// 구조적 실패(형식 불일치·저장소 손상)의 구분 자체는 도메인 규칙**입니다.
    var isRecoverableByRetry: Bool {
        switch self {
        case .offline, .rateLimited, .network: true
        case .storage, .decoding: false
        }
    }
}
