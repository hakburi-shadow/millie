import Foundation

/// 이미지 한 장의 메타데이터입니다.
///
/// 저장소 경계를 넘나드는 유일한 표현입니다. Realm 의 `Object` 는 만들어진 스레드에서만
/// 접근할 수 있고 `Sendable` 이 아니므로, `Core_Persistence` 가 경계에서 반드시 이 값 타입으로
/// 변환해 내보냅니다. 그 덕분에 액터 사이를 자유롭게 오갈 수 있고, 저장 기술을 바꿔도
/// 이 타입은 그대로입니다.
public struct Photo: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let width: Int
    public let height: Int

    public init(id: String, url: URL, width: Int, height: Int) {
        self.id = id
        self.url = url
        self.width = width
        self.height = height
    }
}
