import Core_Domain
import Foundation

/// 실패를 화면에 보일 문장으로 옮깁니다.
///
/// 이 매핑을 도메인이 아니라 앱에 두는 이유가 있습니다. 문장은 언어와 말투에 따라 달라지는
/// 화면의 몫이고, 도메인이 그것을 알면 저장·네트워크 계층까지 화면에 묶입니다.
extension AppError {
    /// 보여줄 것이 **하나도 없을 때**의 문구입니다. 화면 전체가 이 문구로 채워집니다.
    var message: String {
        switch self {
        case .offline:
            "연결이 없고 저장된 이미지도 없어요."
        case .rateLimited(let retryAfter):
            "요청이 많아요. \(retryHint(retryAfter))"
        case .network:
            "이미지를 불러오지 못했어요."
        case .storage:
            "저장된 데이터를 읽지 못했어요."
        case .decoding:
            "서버 응답을 이해하지 못했어요."
        }
    }

    /// 저장된 것으로 대체해 **보여줄 것이 있을 때**의 문구입니다. 목록 위에 띠로 얹힙니다.
    ///
    /// 같은 실패라도 화면에 이미지가 있는지에 따라 할 말이 달라집니다.
    /// 이미지가 가득한 화면에 "저장된 이미지도 없어요"를 띄우면 화면과 안내가 서로 어긋납니다.
    /// 문구를 둘로 나누는 대신 실패 종류를 늘리지 않은 이유는, 이것이 실패의 성질이 아니라
    /// **화면의 사정**이기 때문입니다. 도메인은 무엇이 실패했는지만 알면 됩니다.
    var fallbackMessage: String {
        switch self {
        case .offline:
            "연결이 없어 저장된 이미지를 보여주고 있어요."
        case .rateLimited(let retryAfter):
            "요청이 많아 저장된 이미지를 보여주고 있어요. \(retryHint(retryAfter))"
        case .network, .decoding:
            "새로 불러오지 못해 저장된 이미지를 보여주고 있어요."
        case .storage:
            "저장된 데이터를 읽지 못했어요."
        }
    }

    /// 서버가 대기 시간을 알려줬으면 그대로 전하고, 아니면 두루뭉술하게 둡니다.
    private func retryHint(_ retryAfter: TimeInterval?) -> String {
        guard let retryAfter else { return "잠시 후 다시 시도해 주세요." }
        return "\(Int(retryAfter))초 뒤에 다시 시도해 주세요."
    }
}
