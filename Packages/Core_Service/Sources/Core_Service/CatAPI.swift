import Core_Networking
import Foundation

/// TheCatAPI 의 주소와 파라미터입니다.
///
/// 특정 외부 서비스에 묶이는 지식이라 전송 계층(`Core_Networking`)이 아니라 여기 둡니다.
/// 서비스가 바뀌면 이 파일만 바뀝니다.
public enum CatAPI {
    public static let baseURL = URL(string: "https://api.thecatapi.com/v1")!

    /// `GET /v1/images/search?limit=N`
    ///
    /// 이 API 에는 페이지 개념이 없습니다. `page=0` 과 `order=ASC` 를 붙여 두 번 불러도
    /// 겹치지 않는 다른 묶음이 옵니다(확인함). 그래서 이어서 불러오기는 "다음 페이지 요청"이 아니라
    /// "무작위 묶음을 중복 제거하며 이어붙이기"로 구현합니다.
    ///
    /// 이미 본 id 가 섞여 오는 비율은 표본 100건에서 1% 였습니다.
    public static func search(limit: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "images/search",
            queryItems: [URLQueryItem(name: "limit", value: String(limit))]
        )
    }
}
