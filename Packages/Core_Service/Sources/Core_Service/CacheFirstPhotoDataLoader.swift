import Core_Domain
import Core_Networking
import Core_Persistence
import Foundation

/// 저장된 이미지를 먼저 쓰고, 없을 때만 내려받습니다.
///
/// 연결이 있어도 저장된 것이 있으면 그것을 씁니다. 한 번 받은 이미지는 바뀌지 않으므로
/// 다시 받을 이유가 없고, 데이터와 시간을 아낍니다.
/// 메타데이터가 네트워크 우선인 것(`NetworkFirstPhotoRepository`)과 반대 방향입니다.
public struct CacheFirstPhotoDataLoader: PhotoDataLoader {
    private let cache: ImageDiskCache
    private let downloader: DataDownloader

    public init(cache: ImageDiskCache, downloader: DataDownloader) {
        self.cache = cache
        self.downloader = downloader
    }

    public func data(for url: URL) async throws(AppError) -> Data {
        if let stored = await cache.data(for: url) {
            return stored
        }

        let downloaded: Data
        do {
            downloaded = try await downloader.data(from: url)
        } catch {
            throw error == .offline ? .offline : .network
        }

        await cache.store(downloaded, for: url)
        return downloaded
    }
}
