import Core_Domain

/// 실패를 화면에 보일 문장으로 옮깁니다.
///
/// 이 매핑을 도메인이 아니라 앱에 두는 이유가 있습니다. 문장은 언어와 말투에 따라 달라지는
/// 화면의 몫이고, 도메인이 그것을 알면 저장·네트워크 계층까지 화면에 묶입니다.
extension AppError {
    var message: String {
        switch self {
        case .offlineAndEmpty:
            "연결이 없고 저장된 이미지도 없어요."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "요청이 많아요. \(Int(retryAfter))초 뒤에 다시 시도해 주세요."
            } else {
                "요청이 많아요. 잠시 후 다시 시도해 주세요."
            }
        case .network:
            "이미지를 불러오지 못했어요."
        case .storage:
            "저장된 데이터를 읽지 못했어요."
        case .decoding:
            "서버 응답을 이해하지 못했어요."
        }
    }
}
