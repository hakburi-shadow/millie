import Core_Domain
import Core_Networking
import Core_Persistence
import Foundation

/// 네트워크를 먼저 시도하고, 실패하면 저장된 것으로 대체합니다.
///
/// 메타데이터는 최신이어야 하므로 네트워크가 우선입니다.
/// 이미지 바이너리는 반대로 캐시가 우선인데(`CacheFirstPhotoDataLoader`),
/// 한 번 받은 이미지는 바뀌지 않기 때문입니다.
public struct NetworkFirstPhotoRepository: PhotoRepository {
    private let client: HTTPClient
    private let store: MetadataStore

    public init(client: HTTPClient, store: MetadataStore) {
        self.client = client
        self.store = store
    }

    public func loadNext(limit: Int, excludingIDs: Set<String>) async throws(AppError) -> PhotoPage {
        let received: [PhotoDTO]
        do {
            received = try await client.send(CatAPI.search(limit: limit), as: [PhotoDTO].self)
        } catch {
            return try await loadStored(limit: limit, excludingIDs: excludingIDs, after: error)
        }

        let photos = received.makeDomain()

        // 받은 것은 전부 저장하고, 화면에는 아직 없는 것만 돌려줍니다.
        // 저장은 나중에 오프라인이 됐을 때를 위한 것이라 화면에 보이는 것과 범위가 다릅니다.
        //
        // 저장 실패는 위로 올리지 않습니다. 지금 화면에 보여줄 데이터는 이미 손에 있고,
        // 여기서 실패로 처리하면 정상적으로 받아온 응답을 버리게 됩니다.
        try? await store.upsert(photos)

        let fresh = photos.filter { !excludingIDs.contains($0.id) }
        return PhotoPage(photos: fresh, source: .network)
    }

    /// 네트워크가 실패했을 때 저장된 것으로 대체합니다.
    ///
    /// 저장된 것도 없을 때만 실패로 처리합니다. 연결이 없어도 보여줄 것이 있으면
    /// 화면은 정상이기 때문입니다.
    private func loadStored(
        limit: Int,
        excludingIDs: Set<String>,
        after cause: NetworkError
    ) async throws(AppError) -> PhotoPage {
        let stored: [Photo]
        do {
            stored = try await store.fetchShuffled(limit: limit, excludingIDs: excludingIDs)
        } catch {
            throw AppError.storage
        }

        guard !stored.isEmpty else {
            throw Self.mapToAppError(cause)
        }
        return PhotoPage(photos: stored, source: .cache)
    }

    /// 전송 계층의 실패를 화면이 이해하는 표현으로 옮깁니다.
    ///
    /// 이 변환이 일어나는 시점은 **저장된 것도 없을 때**뿐이라,
    /// 연결이 없는 경우가 곧 "보여줄 것이 아무것도 없음"이 됩니다.
    static func mapToAppError(_ error: NetworkError) -> AppError {
        switch error {
        case .offline:
            .offlineAndEmpty
        case .rateLimited(let retryAfter):
            .rateLimited(retryAfter: retryAfter)
        case .decoding:
            .decoding
        case .timeout, .server, .client, .transport, .invalidURL:
            .network
        }
    }
}
