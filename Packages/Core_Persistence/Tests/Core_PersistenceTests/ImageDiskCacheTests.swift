import Testing
import Foundation
@testable import Core_Persistence

private func makeSUT() -> ImageDiskCache {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return ImageDiskCache(directory: directory)
}

private let anyURL = URL(string: "https://example.com/a.jpg")!
private let anyData = Data("image-bytes".utf8)

@Suite("ImageDiskCache")
struct ImageDiskCacheTests {
    @Test("저장한 것을 그대로 돌려줍니다")
    func store_thenRead() async {
        let sut = makeSUT()

        await sut.store(anyData, for: anyURL)

        #expect(await sut.data(for: anyURL) == anyData)
    }

    @Test("저장하지 않은 주소는 nil 입니다")
    func read_unknownURL_isNil() async {
        let sut = makeSUT()

        #expect(await sut.data(for: anyURL) == nil)
    }

    /// 메모리 캐시가 비어 있어도 디스크에서 찾아야 합니다.
    /// 앱을 껐다 켠 뒤에도 저장된 이미지를 쓸 수 있어야 하기 때문입니다.
    @Test("메모리 캐시가 없는 새 인스턴스도 디스크에서 찾습니다")
    func read_fromDiskWithColdMemory() async {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let writer = ImageDiskCache(directory: directory)
        await writer.store(anyData, for: anyURL)

        let reader = ImageDiskCache(directory: directory) // 메모리 캐시가 빈 상태

        #expect(await reader.data(for: anyURL) == anyData)
    }

    @Test("주소가 다르면 다른 파일명을 씁니다")
    func key_differsByURL() {
        let a = ImageDiskCache.key(for: URL(string: "https://example.com/a.jpg")!)
        let b = ImageDiskCache.key(for: URL(string: "https://example.com/b.jpg")!)

        #expect(a != b)
        #expect(a.count == 64) // SHA-256 을 16진수로 표기한 길이
    }
}
