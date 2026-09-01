import Core_Domain
import Core_Networking
import Core_Persistence
import Core_Service
import SwiftUI

@main
struct MillieCatApp: App {
    /// 구현체를 고르고 이어 붙이는 유일한 곳입니다.
    ///
    /// 화면과 상태 계층은 `PhotoRepository` · `PhotoDataLoader` 라는 계약만 알고,
    /// 그 자리에 무엇이 들어가는지는 여기서만 정합니다.
    /// 덕분에 테스트에서는 같은 자리에 대역을 넣어 화면 밖에서 동작을 확인할 수 있습니다.
    private let repository: NetworkFirstPhotoRepository
    private let loader: CacheFirstPhotoDataLoader

    init() {
        let client = URLSessionHTTPClient()
        repository = NetworkFirstPhotoRepository(client: client, store: MetadataStore())
        loader = CacheFirstPhotoDataLoader(cache: ImageDiskCache(), downloader: client)
    }

    var body: some Scene {
        WindowGroup {
            PhotoListView(repository: repository, loader: loader)
        }
    }
}
