import Testing
import Foundation
import Core_Domain
import Core_Networking
import Core_Persistence
@testable import Core_Service

/// 내려받기 횟수를 셀 수 있는 대역입니다.
///
/// 호출 수를 세려면 상태가 필요한데, `NSLock` 은 async 안에서 쓸 수 없습니다.
/// actor 로 두면 격리가 언어 차원에서 보장되어 잠금을 직접 다루지 않아도 됩니다.
private actor CountingDownloader: DataDownloader {
    private(set) var callCount = 0
    let payload: Data
    let failure: NetworkError?

    init(payload: Data = Data("downloaded".utf8), failure: NetworkError? = nil) {
        self.payload = payload
        self.failure = failure
    }

    func data(from url: URL) async throws(NetworkError) -> Data {
        callCount += 1
        if let failure { throw failure }
        return payload
    }
}

private func makeCache() -> ImageDiskCache {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return ImageDiskCache(directory: directory)
}

private let anyURL = URL(string: "https://cdn.example.com/a.jpg")!

@Suite("CacheFirstPhotoDataLoader")
struct CacheFirstPhotoDataLoaderTests {

    @Test("저장된 것이 없으면 내려받아 돌려줍니다")
    func miss_downloads() async throws {
        let downloader = CountingDownloader()
        let sut = CacheFirstPhotoDataLoader(cache: makeCache(), downloader: downloader)

        let data = try await sut.data(for: anyURL)

        #expect(data == downloader.payload)
        #expect(await downloader.callCount == 1)
    }

    /// 연결이 있어도 저장된 것이 있으면 그것을 씁니다.
    /// 한 번 받은 이미지는 바뀌지 않으므로 다시 받을 이유가 없습니다.
    @Test("한 번 받은 뒤에는 다시 내려받지 않습니다")
    func hit_doesNotDownloadAgain() async throws {
        let downloader = CountingDownloader()
        let sut = CacheFirstPhotoDataLoader(cache: makeCache(), downloader: downloader)

        _ = try await sut.data(for: anyURL)
        _ = try await sut.data(for: anyURL)
        _ = try await sut.data(for: anyURL)

        #expect(await downloader.callCount == 1)
    }

    @Test("저장된 것도 없고 연결도 없으면 실패로 처리합니다")
    func miss_whileOffline_throws() async {
        let sut = CacheFirstPhotoDataLoader(
            cache: makeCache(),
            downloader: CountingDownloader(failure: .offline)
        )

        await #expect(throws: AppError.offline) {
            try await sut.data(for: anyURL)
        }
    }

    /// 연결이 끊겨도 이미 받아 둔 이미지는 보여야 합니다.
    @Test("연결이 없어도 저장된 것이 있으면 돌려줍니다")
    func hit_whileOffline_returnsStored() async throws {
        let cache = makeCache()
        let stored = Data("stored".utf8)
        await cache.store(stored, for: anyURL)

        let sut = CacheFirstPhotoDataLoader(
            cache: cache,
            downloader: CountingDownloader(failure: .offline)
        )

        #expect(try await sut.data(for: anyURL) == stored)
    }
}
