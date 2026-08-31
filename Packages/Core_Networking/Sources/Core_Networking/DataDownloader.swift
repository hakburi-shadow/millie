import Foundation

/// 주소에서 바이너리를 그대로 받아옵니다.
///
/// `HTTPClient` 와 나눈 이유가 있습니다. `HTTPClient` 는 우리가 조립한 `Endpoint` 로 요청하고
/// JSON 을 디코딩해 돌려주는데, 이미지는 응답에 들어 있던 **완성된 주소**를 그대로 받아
/// 바이트를 쓰기 때문에 요청을 조립할 일도 디코딩할 일도 없습니다.
public protocol DataDownloader: Sendable {
    func data(from url: URL) async throws(NetworkError) -> Data
}
