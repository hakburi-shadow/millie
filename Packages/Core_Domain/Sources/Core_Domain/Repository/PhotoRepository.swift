import Foundation

/// 목록 데이터를 어디서 가져왔는지 나타냅니다.
///
/// 화면이 "지금 저장된 것을 보고 있다"를 알아야 오프라인 안내를 띄울 수 있습니다.
public enum PhotoSource: Equatable, Sendable {
    case network
    case cache
}

public struct PhotoPage: Equatable, Sendable {
    public let photos: [Photo]
    public let source: PhotoSource

    public init(photos: [Photo], source: PhotoSource) {
        self.photos = photos
        self.source = source
    }
}

/// 목록 데이터의 단일 진입점입니다.
///
/// 구현체가 온라인 호출과 저장된 데이터로의 대체를 캡슐화합니다.
/// 호출하는 쪽은 URLSession 도 Realm 도 알지 못합니다.
public protocol PhotoRepository: Sendable {
    /// 다음 묶음을 가져옵니다.
    ///
    /// - 온라인: API 호출 → 로컬에 저장 → 받은 결과 반환
    /// - 실패·오프라인: 저장된 것을 **무작위 순서로** 반환
    ///
    /// - Parameter excludingIDs: 이미 화면에 있는 id 입니다.
    ///   이 API 는 실제 페이지네이션이 없어 매 호출이 무작위이고 같은 id 가 반복 반환됩니다(실측).
    ///   그래서 무한 스크롤이 "다음 페이지 요청"이 아니라
    ///   "무작위 묶음을 중복 제거하며 이어붙이기"가 되고, 걸러낼 대상을 호출자가 알려줍니다.
    func loadNext(limit: Int, excludingIDs: Set<String>) async throws(AppError) -> PhotoPage
}

/// 이미지 바이너리를 가져옵니다. 메모리 → 디스크 → 네트워크 순으로 조회합니다.
///
/// 오프라인일 때는 물론 **온라인이어도 저장된 것이 있으면 그것을 사용합니다.**
///
/// 메타데이터(Realm)와 저장 위치가 다르기 때문에 `PhotoRepository` 와 분리했습니다.
public protocol PhotoDataLoader: Sendable {
    func data(for url: URL) async throws(AppError) -> Data
}
