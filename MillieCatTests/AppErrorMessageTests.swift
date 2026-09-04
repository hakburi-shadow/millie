import Core_Domain
import Testing
@testable import MillieCat

/// 실패를 문장으로 옮기는 부분입니다.
///
/// 문구를 테스트하는 것이 지나쳐 보일 수 있지만, 여기서 실제로 틀린 안내가 나갔습니다 —
/// 호출 제한(429)에 걸렸는데 "연결이 없어서"라고 말했습니다. 화면이 원인을 짐작한 탓이었고,
/// 짐작이 들어갈 자리가 남아 있는지는 문구를 직접 확인해야 드러납니다.
@Suite("AppError 문구")
struct AppErrorMessageTests {

    // MARK: - 원인을 구분해서 말하는가

    /// 연결 없음과 호출 제한은 사용자가 할 수 있는 일이 서로 다릅니다 —
    /// 하나는 연결을 확인하는 것이고 하나는 기다리는 것입니다.
    @Test("호출 제한을 연결 문제로 말하지 않습니다")
    func rateLimited_doesNotMentionConnection() {
        let rateLimited = AppError.rateLimited(retryAfter: 30)

        #expect(!rateLimited.message.contains("연결"))
        #expect(!rateLimited.fallbackMessage.contains("연결"))
    }

    @Test("호출 제한은 요청이 많다는 사실을 밝힙니다")
    func rateLimited_mentionsTraffic() {
        let rateLimited = AppError.rateLimited(retryAfter: 30)

        #expect(rateLimited.message.contains("요청이 많"))
        #expect(rateLimited.fallbackMessage.contains("요청이 많"))
    }

    /// 서버가 알려준 대기 시간은 버리지 않습니다. 저장분으로 대체한 경우에도 마찬가지입니다.
    @Test("서버가 알려준 대기 시간을 그대로 전합니다")
    func rateLimited_carriesRetryAfter() {
        #expect(AppError.rateLimited(retryAfter: 30).message.contains("30초"))
        #expect(AppError.rateLimited(retryAfter: 30).fallbackMessage.contains("30초"))
    }

    @Test("대기 시간을 모르면 시간을 지어내지 않습니다")
    func rateLimited_withoutRetryAfter_staysVague() {
        let unknown = AppError.rateLimited(retryAfter: nil)

        #expect(unknown.message.contains("잠시 후"))
        #expect(!unknown.message.contains("0초"))
    }

    // MARK: - 화면에 보여줄 것이 있는가에 따라

    /// 이미지가 가득한 화면에 "저장된 이미지도 없어요"를 띄우면
    /// 화면과 안내가 서로 어긋납니다. 실제로 오프라인에서 끝까지 스크롤하면 그렇게 됐습니다.
    @Test("보여줄 것이 있을 때는 없다고 말하지 않습니다")
    func fallbackMessage_neverClaimsEmptiness() {
        for error in [AppError.offline, .rateLimited(retryAfter: 30), .network, .decoding] {
            #expect(!error.fallbackMessage.contains("없어요"), "\(error) 의 대체 문구가 없다고 말합니다")
        }
    }

    @Test("보여줄 것이 있을 때는 저장된 것을 보고 있다고 밝힙니다")
    func fallbackMessage_explainsWhatIsShown() {
        for error in [AppError.offline, .rateLimited(retryAfter: 30), .network, .decoding] {
            #expect(
                error.fallbackMessage.contains("저장된 이미지를 보여주고"),
                "\(error) 의 대체 문구가 무엇을 보고 있는지 밝히지 않습니다"
            )
        }
    }

    /// 보여줄 것이 아무것도 없을 때만 "없다"고 말합니다.
    @Test("아무것도 없을 때의 오프라인 문구는 그 사실을 밝힙니다")
    func message_whenOfflineAndNothingToShow() {
        #expect(AppError.offline.message.contains("저장된 이미지도 없어요"))
    }

    /// 같은 실패라도 화면 사정에 따라 할 말이 달라집니다.
    @Test("같은 실패라도 두 문구는 서로 다릅니다")
    func message_andFallbackMessage_differ() {
        for error in [AppError.offline, .rateLimited(retryAfter: 30), .network] {
            #expect(error.message != error.fallbackMessage, "\(error) 의 두 문구가 같습니다")
        }
    }
}
