import Testing
import Foundation
import Core_Domain
@testable import Core_Persistence

private func makeSUT() -> MetadataStore {
    // 테스트마다 격리된 Realm 파일을 씁니다.
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("\(UUID().uuidString).realm")
    return MetadataStore(fileURL: url)
}

private func makePhoto(_ id: String) -> Photo {
    Photo(id: id, url: URL(string: "https://example.com/\(id).jpg")!, width: 300, height: 120)
}

@Suite("MetadataStore")
struct MetadataStoreTests {

    /// 이 API 는 같은 id 를 반복해서 돌려줍니다.
    /// 기본 키 덕분에 중복이 레코드 수준에서 걸러지는지 확인합니다.
    @Test("같은 id 를 다시 저장해도 레코드는 하나입니다")
    func upsert_sameID_keepsSingleRecord() async throws {
        let sut = makeSUT()

        try await sut.upsert([makePhoto("736")])
        try await sut.upsert([makePhoto("736")])

        #expect(try await sut.count() == 1)
    }

    @Test("저장한 것을 값 타입으로 돌려줍니다")
    func fetchShuffled_returnsStoredPhotos() async throws {
        let sut = makeSUT()
        try await sut.upsert([makePhoto("a"), makePhoto("b"), makePhoto("c")])

        let result = try await sut.fetchShuffled()

        #expect(Set(result.map(\.id)) == ["a", "b", "c"])
    }

    @Test("이미 화면에 있는 id 는 제외합니다")
    func fetchShuffled_excludesGivenIDs() async throws {
        let sut = makeSUT()
        try await sut.upsert([makePhoto("a"), makePhoto("b")])

        let result = try await sut.fetchShuffled(excludingIDs: ["a"])

        #expect(result.map(\.id) == ["b"])
    }

    @Test("limit 을 주면 그만큼만 돌려줍니다")
    func fetchShuffled_respectsLimit() async throws {
        let sut = makeSUT()
        try await sut.upsert((0..<10).map { makePhoto("\($0)") })

        let result = try await sut.fetchShuffled(limit: 3)

        #expect(result.count == 3)
    }

    /// 네트워크가 끊겼을 때 매번 같은 순서로 나오면 갱신되지 않는 화면처럼 보입니다.
    ///
    /// 20건을 여러 번 조회해서 한 번이라도 순서가 달라지는지 봅니다.
    /// 20건이 매번 같은 순서로 나올 확률은 사실상 0 이라 안정적으로 판정됩니다.
    @Test("조회할 때마다 순서가 섞입니다")
    func fetchShuffled_ordersRandomly() async throws {
        let sut = makeSUT()
        try await sut.upsert((0..<20).map { makePhoto("\($0)") })

        let first = try await sut.fetchShuffled().map(\.id)
        var sawDifferentOrder = false
        for _ in 0..<5 where try await sut.fetchShuffled().map(\.id) != first {
            sawDifferentOrder = true
            break
        }

        #expect(sawDifferentOrder)
    }
}
