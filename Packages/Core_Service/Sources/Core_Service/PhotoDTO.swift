import Core_Domain
import Foundation

/// API 응답 형식입니다.
///
/// ```json
/// [{"id":"ckb","url":"https://.../ckb.jpg","width":450,"height":299}]
/// ```
///
/// 서버 표현(`url` 이 문자열)과 도메인 표현(`Photo.url` 이 `URL`)을 분리해 두었습니다.
/// 도메인이 서버 형식에 묶이지 않게 하려는 것이고, 변환은 아래 한 곳에서만 일어납니다.
public struct PhotoDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let url: String
    public let width: Int
    public let height: Int
}

public extension PhotoDTO {
    /// 주소가 URL 로 해석되지 않으면 버립니다.
    func makeDomain() -> Photo? {
        guard let url = URL(string: url) else { return nil }
        return Photo(id: id, url: url, width: width, height: height)
    }
}

public extension Array where Element == PhotoDTO {
    /// 변환할 수 없는 항목은 조용히 제외합니다.
    ///
    /// 한 장이 깨졌다고 목록 전체를 실패시키는 것보다, 나머지를 보여주는 편이 낫습니다.
    func makeDomain() -> [Photo] {
        compactMap { $0.makeDomain() }
    }
}
