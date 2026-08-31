import Core_Domain
import Foundation
import ThirdParty_Realm

/// 이미지 메타데이터 저장소입니다.
///
/// **경계 규칙**: 모든 public 메서드는 Realm 타입이 아니라 `Photo` 값 타입으로 주고받습니다.
/// `Results<PhotoObject>` 나 `PhotoObject` 는 이 타입 밖으로 나가지 않습니다.
public actor MetadataStore {
    private let configuration: Realm.Configuration

    /// - Parameter fileURL: nil 이면 기본 경로를 씁니다. 테스트에서는 임시 경로를 넣습니다.
    public init(fileURL: URL? = nil) {
        var configuration = Realm.Configuration.defaultConfiguration
        if let fileURL {
            configuration.fileURL = fileURL
        }
        configuration.objectTypes = [PhotoObject.self]
        configuration.schemaVersion = 1
        self.configuration = configuration
    }

    /// Realm 인스턴스를 프로퍼티로 들고 있지 않고 메서드마다 새로 엽니다.
    ///
    /// actor 는 호출 사이에 같은 스레드를 보장하지 않는데 Realm 인스턴스는 스레드에 묶여 있어서,
    /// 한 번 만들어 재사용하면 다른 스레드에서 접근하는 순간 깨집니다.
    /// Realm 이 내부적으로 스레드별 캐시를 두므로 매번 여는 비용은 크지 않습니다.
    private func openRealm() throws(AppError) -> Realm {
        do {
            return try Realm(configuration: configuration)
        } catch {
            throw AppError.storage
        }
    }

    /// id 를 기준으로 저장하거나 갱신합니다.
    ///
    /// `id` 가 기본 키라 같은 id 가 다시 들어와도 레코드가 하나로 유지됩니다.
    /// 이 API 는 같은 id 를 반복해서 돌려주므로 이 동작이 필요합니다.
    public func upsert(_ photos: [Photo]) throws(AppError) {
        let realm = try openRealm()
        let now = Date()
        do {
            try realm.write {
                for photo in photos {
                    realm.add(
                        PhotoObject(
                            id: photo.id,
                            urlString: photo.url.absoluteString,
                            width: photo.width,
                            height: photo.height,
                            fetchedAt: now
                        ),
                        update: .modified
                    )
                }
            }
        } catch {
            throw AppError.storage
        }
    }

    /// 저장된 것을 **무작위 순서로** 돌려줍니다.
    ///
    /// 네트워크가 끊겼을 때 저장된 데이터를 보여주는데, 매번 같은 순서로 나오면
    /// 갱신되지 않는 화면처럼 보입니다. 그래서 순서를 섞습니다.
    public func fetchShuffled(
        limit: Int? = nil,
        excludingIDs: Set<String> = []
    ) throws(AppError) -> [Photo] {
        let realm = try openRealm()
        let shuffled = realm.objects(PhotoObject.self)
            .filter { !excludingIDs.contains($0.id) }
            .compactMap(Self.makeDomain)
            .shuffled()
        guard let limit else { return shuffled }
        return Array(shuffled.prefix(limit))
    }

    public func count() throws(AppError) -> Int {
        try openRealm().objects(PhotoObject.self).count
    }

    /// Realm 객체를 값 타입으로 옮깁니다. **경계는 이 한 곳뿐입니다.**
    ///
    /// URL 로 해석되지 않는 항목은 버립니다. 한 건이 깨졌다고 목록 전체를 잃는 것보다 낫습니다.
    private static func makeDomain(_ object: PhotoObject) -> Photo? {
        guard let url = URL(string: object.urlString) else { return nil }
        return Photo(id: object.id, url: url, width: object.width, height: object.height)
    }
}
