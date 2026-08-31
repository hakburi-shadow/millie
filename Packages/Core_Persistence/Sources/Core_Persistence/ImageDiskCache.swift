import CryptoKit
import Foundation

/// 이미지 바이너리를 메모리와 디스크 두 단계로 보관합니다.
///
/// 메타데이터는 Realm 에, 바이너리는 여기 파일시스템에 둡니다.
/// 큰 바이너리를 DB 에 넣으면 파일 크기·마이그레이션·메모리 모두 불리합니다.
///
/// **네트워크는 다루지 않습니다.** 없으면 `nil` 을 돌려줄 뿐이고,
/// 내려받아 채우는 일은 이 모듈이 알 수 없는 영역이라 조합 계층의 몫입니다.
public actor ImageDiskCache {
    private let directory: URL
    private let memory = NSCache<NSString, NSData>()

    /// - Parameter directory: nil 이면 시스템 캐시 폴더 아래를 씁니다.
    ///   사용자 데이터가 아니므로 문서 폴더가 아니라 캐시 폴더에 둡니다.
    ///   용량이 부족하면 OS 가 정리할 수 있고, 백업 대상에서도 빠집니다.
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoImages", isDirectory: true)
    }

    /// 메모리 → 디스크 순으로 찾습니다. 둘 다 없으면 `nil` 입니다.
    ///
    /// 디스크에서 찾으면 메모리에도 올려 다음 조회를 빠르게 합니다.
    public func data(for url: URL) -> Data? {
        let key = Self.key(for: url)
        if let cached = memory.object(forKey: key as NSString) {
            return cached as Data
        }
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        memory.setObject(data as NSData, forKey: key as NSString)
        return data
    }

    /// 메모리와 디스크 양쪽에 씁니다.
    ///
    /// 디스크 쓰기가 실패해도 오류를 올리지 않습니다. 캐시를 채우지 못한 것뿐이고
    /// 화면에는 이미 메모리에 올린 이미지가 그대로 보입니다.
    /// 여기서 실패를 위로 던지면 정상 동작을 실패로 만들게 됩니다.
    public func store(_ data: Data, for url: URL) {
        let key = Self.key(for: url)
        memory.setObject(data as NSData, forKey: key as NSString)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key)
    }

    /// URL 을 그대로 파일명으로 쓸 수 없어서(길이 제한과 `/` 같은 문자) 해시를 씁니다.
    static func key(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
