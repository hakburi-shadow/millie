import Testing
@testable import Core_Domain

@Suite("AppError")
struct AppErrorTests {
    @Test("일시적 실패는 재시도로 회복 가능합니다")
    func isRecoverableByRetry_transientFailures() {
        #expect(AppError.offline.isRecoverableByRetry)
        #expect(AppError.rateLimited(retryAfter: 3).isRecoverableByRetry)
        #expect(AppError.network.isRecoverableByRetry)
    }

    @Test("구조적 실패는 재시도해도 소용없습니다")
    func isRecoverableByRetry_structuralFailures() {
        #expect(!AppError.storage.isRecoverableByRetry)
        #expect(!AppError.decoding.isRecoverableByRetry)
    }

    /// 오프라인이어도 저장된 데이터가 있으면 화면은 정상이므로,
    /// "오프라인"과 그 밖의 네트워크 실패는 서로 다른 상태여야 합니다.
    @Test("오프라인은 일반 네트워크 실패와 구분됩니다")
    func offline_isDistinctFromNetwork() {
        #expect(AppError.offline != AppError.network)
    }

    /// 대체한 원인을 `PhotoSource` 가 실어 나르는지 확인합니다.
    /// 이것이 없으면 화면은 원인을 짐작할 수밖에 없고, 429 를 두고 "연결이 없다"고 말하게 됩니다.
    @Test("저장분으로 대체한 원인을 꺼낼 수 있습니다")
    func fallbackReason_isCarriedByCacheSource() {
        #expect(PhotoSource.cache(reason: .rateLimited(retryAfter: 30)).fallbackReason
            == .rateLimited(retryAfter: 30))
        #expect(PhotoSource.cache(reason: .offline).fallbackReason == .offline)
    }

    @Test("네트워크에서 온 것에는 대체 원인이 없습니다")
    func fallbackReason_isNilForNetwork() {
        #expect(PhotoSource.network.fallbackReason == nil)
    }

    /// 원인이 다르면 서로 다른 값이어야 합니다.
    /// 같은 값으로 뭉개지면 화면은 다시 원인을 구분하지 못합니다.
    @Test("원인이 다른 대체는 서로 다른 값입니다")
    func cacheSource_distinguishesReasons() {
        #expect(PhotoSource.cache(reason: .offline) != PhotoSource.cache(reason: .network))
    }
}
