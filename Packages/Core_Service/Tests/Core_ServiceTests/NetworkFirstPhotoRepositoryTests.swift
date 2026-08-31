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

        #expect(page.source == .cache)
        #expect(page.photos.map(\.id) == ["x"])
    }

    /// 연결이 없어도 보여줄 것이 있으면 화면은 정상입니다.
    /// 둘 다 없을 때만 실패로 처리합니다.
    @Test("네트워크도 저장된 것도 없으면 실패로 처리합니다")
    func failure_withEmptyStore_throws() async {
        let sut = NetworkFirstPhotoRepository(
            client: StubHTTPClient(failure: .offline),
            store: makeStore()
        )

        await #expect(throws: AppError.offlineAndEmpty) {
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
