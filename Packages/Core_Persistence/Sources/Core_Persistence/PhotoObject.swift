import Foundation
import ThirdParty_Realm

/// Realm 저장 스키마입니다. **`public` 을 붙이지 않습니다.**
///
/// 이 타입이 패키지 밖으로 나가지 않는 것이 이 모듈 설계의 핵심입니다.
/// Realm `Object` 는 만들어진 스레드에서만 접근할 수 있고 `Sendable` 이 아니므로,
/// 경계를 넘는 순간 Swift 6 동시성 검사와 충돌합니다.
/// 접근 제어로 애초에 새어 나갈 수 없게 만듭니다.
///
/// 이미지 바이너리는 여기 담지 않습니다. 로컬 DB 에는 메타데이터만 두고,
/// 바이너리는 파일시스템(`ImageDiskCache`)에 둡니다.
final class PhotoObject: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var urlString: String = ""
    @Persisted var width: Int = 0
    @Persisted var height: Int = 0
    /// 저장 시각입니다. 신선도 판단과 정렬 보조에 씁니다.
    @Persisted var fetchedAt: Date = .distantPast

    convenience init(id: String, urlString: String, width: Int, height: Int, fetchedAt: Date) {
        self.init()
        self.id = id
        self.urlString = urlString
        self.width = width
        self.height = height
        self.fetchedAt = fetchedAt
    }
}
