import Foundation

/// 목록 데이터를 어디서 가져왔는지 나타냅니다.
///
/// 화면이 "지금 저장된 것을 보고 있다"를 알아야 안내를 띄울 수 있습니다.
public enum PhotoSource: Equatable, Sendable {
    case network
    /// 네트워크가 실패해 저장된 것으로 대체했습니다. `reason` 은 그 실패입니다.
    ///
    /// **원인을 함께 나릅니다.** 대체했다는 사실만 전하면 화면은 원인을 알 수 없어
    /// 한 가지 문구로 뭉뚱그리게 됩니다. 실제로 그랬습니다 — 호출 제한(429)에 걸렸는데도
    /// "연결이 없어서"라고 안내했습니다. 연결 없음과 호출 제한은 사용자가 할 수 있는 일이
    /// 서로 달라서(기다리기 / 연결 확인하기) 화면에서 구분되어야 합니다.
    case cache(reason: AppError)
}

public extension PhotoSource {
    /// 저장된 것으로 대체했다면 그 원인입니다. 네트워크에서 온 것이면 `nil` 입니다.
    var fallbackReason: AppError? {
        guard case .cache(let reason) = self else { return nil }
        return reason
    }
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
    /// - 실패·오프라인: 저장된 것을 **무작위 순서로** 반환(`source` 에 원인을 담아서)
    ///
    /// 빈 묶음(`photos` 가 `[]`)은 실패가 아니라 **더 없음**입니다.
    /// 이어서 불러오다 남은 것이 떨어진 경우가 여기 해당합니다. 화면에는 이미 보여줄 것이
    /// 있으므로 실패로 올리면 이미지가 가득한 화면에 "아무것도 없다"는 안내가 붙습니다.
    ///
    /// - Parameter excludingIDs: 이미 화면에 있는 id 입니다.
    ///   이 API 는 실제 페이지네이션이 없어 매 호출이 무작위입니다. `page` 나 `order` 를 붙여도
    ///   같은 조건으로 두 번 부르면 다른 묶음이 옵니다(확인함).
    ///   그래서 무한 스크롤이 "다음 페이지 요청"이 아니라
    ///   "무작위 묶음을 중복 제거하며 이어붙이기"가 되고, 걸러낼 대상을 호출자가 알려줍니다.
    ///
    ///   이미 본 id 가 섞여 오는 비율은 **표본 100건에서 1%** 였습니다. 흔하지는 않지만
    ///   0 은 아니라서, 걸러내지 않으면 같은 이미지가 목록에 두 번 붙습니다.
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
