import Testing
@testable import Core_Domain

@Suite("AppError")
struct AppErrorTests {
    @Test("일시적 실패는 재시도로 회복 가능합니다")
    func isRecoverableByRetry_transientFailures() {
        #expect(AppError.offlineAndEmpty.isRecoverableByRetry)
        #expect(AppError.rateLimited(retryAfter: 3).isRecoverableByRetry)
        #expect(AppError.network.isRecoverableByRetry)
    }

    @Test("구조적 실패는 재시도해도 소용없습니다")
    func isRecoverableByRetry_structuralFailures() {
        #expect(!AppError.storage.isRecoverableByRetry)
        #expect(!AppError.decoding.isRecoverableByRetry)
    }

    /// 오프라인이어도 저장된 데이터가 있으면 화면은 정상이므로,
    /// "오프라인"과 "보여줄 것이 없음"은 서로 다른 상태여야 합니다.
    @Test("오프라인과 빈 캐시는 별개의 case 로 구분됩니다")
    func offlineAndEmpty_isDistinctFromNetwork() {
        #expect(AppError.offlineAndEmpty != AppError.network)
    }
}
