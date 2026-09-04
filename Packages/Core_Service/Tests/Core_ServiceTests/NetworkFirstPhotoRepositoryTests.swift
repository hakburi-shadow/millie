import Testing
import Foundation
import Core_Domain
import Core_Networking
import Core_Persistence
@testable import Core_Service

// MARK: - 테스트 대역

/// 응답을 지정할 수 있는 전송 계층 대역입니다.
private struct StubHTTPClient: HTTPClient, DataDownloader {
    var json: String?
    var failure: NetworkError?

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws(NetworkError) -> T {
        if let failure { throw failure }
        do {
            return try JSONDecoder().decode(T.self, from: Data((json ?? "[]").utf8))
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    func data(from url: URL) async throws(NetworkError) -> Data {
        if let failure { throw failure }
        return Data()
    }
}

private func makeStore() -> MetadataStore {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(UUID().uuidString).realm")
    return MetadataStore(fileURL: url)
}

private func json(ids: [String]) -> String {
    let items = ids.map { #"{"id":"\#($0)","url":"https://e.com/\#($0).jpg","width":300,"height":120}"# }
    return "[\(items.joined(separator: ","))]"
}

// MARK: - 테스트

@Suite("NetworkFirstPhotoRepository")
struct NetworkFirstPhotoRepositoryTests {

    @Test("성공하면 네트워크에서 온 것으로 표시합니다")
    func success_marksSourceAsNetwork() async throws {
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(json: json(ids: ["a", "b"])),
            store: makeStore()
        )

        let page = try await sut.loadNext(limit: 10, excludingIDs: [])

        #expect(page.source == .network)
        #expect(page.photos.map(\.id) == ["a", "b"])
    }

    /// 이 API 는 같은 id 를 반복해서 돌려주므로, 이미 화면에 있는 것은 빼고 줘야 합니다.
    @Test("이미 화면에 있는 id 는 빼고 돌려줍니다")
    func success_filtersAlreadySeenIDs() async throws {
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(json: json(ids: ["a", "b", "c"])),
            store: makeStore()
        )

        let page = try await sut.loadNext(limit: 10, excludingIDs: ["a", "c"])

        #expect(page.photos.map(\.id) == ["b"])
    }

    /// 화면에 보여줄 것과 저장할 것의 범위가 다릅니다.
    /// 나중에 연결이 끊겼을 때를 위해 받은 것은 전부 저장해 둡니다.
    @Test("화면에서 걸러낸 것도 저장은 해 둡니다")
    func success_storesEverythingReceived() async throws {
        let store = makeStore()
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(json: json(ids: ["a", "b", "c"])),
            store: store
        )

        _ = try await sut.loadNext(limit: 10, excludingIDs: ["a", "c"])

        #expect(try await store.count() == 3)
    }

    @Test("네트워크가 실패하면 저장된 것으로 대체하고 그 사실을 알립니다")
    func failure_fallsBackToStored() async throws {
        let store = makeStore()
        try await store.upsert([
            Photo(id: "x", url: URL(string: "https://e.com/x.jpg")!, width: 300, height: 120)
        ])
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .offline),
            store: store
        )

        let page = try await sut.loadNext(limit: 10, excludingIDs: [])

        #expect(page.source == .cache(reason: .offline))
        #expect(page.photos.map(\.id) == ["x"])
    }

    /// 429 는 연결 문제가 아닙니다. 대체했다는 사실만 전하면 화면은 원인을 짐작하게 되고,
    /// 실제로 호출 제한을 두고 "연결이 없다"고 안내했습니다.
    @Test("호출 제한으로 대체했으면 그 원인을 함께 전달합니다")
    func rateLimited_fallsBackCarryingReason() async throws {
        let store = makeStore()
        try await store.upsert([
            Photo(id: "x", url: URL(string: "https://e.com/x.jpg")!, width: 300, height: 120)
        ])
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .rateLimited(retryAfter: 30)),
            store: store
        )

        let page = try await sut.loadNext(limit: 10, excludingIDs: [])

        #expect(page.source == .cache(reason: .rateLimited(retryAfter: 30)))
        #expect(page.photos.map(\.id) == ["x"])
    }

    /// 이어서 불러오다 저장분이 떨어진 것은 실패가 아닙니다.
    /// 호출자는 이미 보여줄 것을 들고 있으므로, 실패로 올리면
    /// 이미지가 가득한 화면에 "아무것도 없다"는 안내가 붙습니다.
    @Test("이어서 불러오다 저장분이 떨어지면 실패가 아니라 빈 묶음입니다")
    func exhaustedWhilePaginating_returnsEmptyPageInsteadOfThrowing() async throws {
        let store = makeStore()
        try await store.upsert([
            Photo(id: "x", url: URL(string: "https://e.com/x.jpg")!, width: 300, height: 120)
        ])
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .offline),
            store: store
        )

        // "x" 는 이미 화면에 있습니다. 저장소에는 그것뿐이라 돌려줄 것이 남지 않습니다.
        let page = try await sut.loadNext(limit: 10, excludingIDs: ["x"])

        #expect(page.photos.isEmpty)
        #expect(page.source == .cache(reason: .offline))
    }

    /// 연결이 없어도 보여줄 것이 있으면 화면은 정상입니다.
    /// 둘 다 없을 때만 실패로 처리합니다.
    @Test("네트워크도 저장된 것도 없으면 실패로 처리합니다")
    func failure_withEmptyStore_throws() async {
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .offline),
            store: makeStore()
        )

        await #expect(throws: AppError.offline) {
            try await sut.loadNext(limit: 10, excludingIDs: [])
        }
    }

    @Test("호출 제한은 대기 시간과 함께 전달합니다")
    func rateLimited_preservesRetryAfter() async {
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .rateLimited(retryAfter: 30)),
            store: makeStore()
        )

        await #expect(throws: AppError.rateLimited(retryAfter: 30)) {
            try await sut.loadNext(limit: 10, excludingIDs: [])
        }
    }
}

@Suite("PhotoDTO")
struct PhotoDTOTests {
    @Test("실제 응답 형식을 읽습니다")
    func decode_realResponseShape() throws {
        let data = Data(#"[{"id":"ckb","url":"https://cdn.example.com/ckb.jpg","width":450,"height":299}]"#.utf8)

        let dtos = try JSONDecoder().decode([PhotoDTO].self, from: data)

        #expect(dtos.count == 1)
        #expect(dtos[0].id == "ckb")
        #expect(dtos[0].width == 450)
    }

    @Test("주소가 URL 로 해석되지 않는 항목만 버리고 나머지는 살립니다")
    func makeDomain_dropsUnparsableAndKeepsRest() {
        let dtos = [
            PhotoDTO(id: "ok", url: "https://e.com/a.jpg", width: 300, height: 120),
            PhotoDTO(id: "bad", url: "", width: 1, height: 1)
        ]

        #expect(dtos.makeDomain().map(\.id) == ["ok"])
    }
}

@Suite("CatAPI")
struct CatAPITests {
    @Test("limit 을 붙인 주소를 만듭니다")
    func search_buildsURLWithLimit() throws {
        let request = try CatAPI.search(limit: 10).makeRequest()

        #expect(request.url?.absoluteString == "https://api.thecatapi.com/v1/images/search?limit=10")
    }
}
