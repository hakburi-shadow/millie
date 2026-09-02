import Core_Domain
import SwiftUI

/// UIKit 으로 만든 상세 화면을 SwiftUI 목록에서 띄우기 위한 연결부입니다.
///
/// 네비게이션 바는 `UINavigationController` 가 제공하는 것을 그대로 씁니다.
/// 바를 불투명하게 두어야 상세 화면의 영역이 바 아래에서 시작하고,
/// 그 덕분에 이미지가 바를 뺀 나머지를 정확히 차지합니다.
struct ImageDetailScreen: UIViewControllerRepresentable {
    let photo: Photo
    let loader: any PhotoDataLoader
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let detail = ImageDetailViewController(photo: photo, loader: loader, onClose: onClose)
        let navigation = UINavigationController(rootViewController: detail)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.isTranslucent = false

        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}
