/// 화면 자동화 테스트가 요소를 찾을 때 쓰는 이름입니다.
///
/// 화면 곳곳에 문자열을 흩어 놓지 않기 위해 앱 쪽에서는 여기로 모읍니다.
///
/// 다만 화면 자동화 테스트는 앱과 **다른 프로세스**에서 돌기 때문에 이 타입을
/// 가져다 쓸 수 없고, 테스트 쪽에 같은 이름을 따로 적어 두어야 합니다.
/// 그래서 이름을 바꿀 때는 양쪽을 함께 고쳐야 합니다.
enum AccessibilityID {
    static let photoCell = "photoCell"
    static let detailImage = "detailImage"
    static let detailBackButton = "detailBackButton"
}
