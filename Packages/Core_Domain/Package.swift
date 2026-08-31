// swift-tools-version: 6.0
import PackageDescription

// 도메인 계층입니다. 아무것도 의존하지 않습니다.
//
// 이 모듈 안에서 `import ThirdParty_Realm` 이나 `import Core_Networking` 을 쓰면
// 컴파일 에러가 납니다. 계층 규칙이 문서가 아니라 컴파일러로 강제되는 지점입니다.
let package = Package(
    name: "Core_Domain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14) // 터미널에서 swift build/test 를 돌리기 위해 선언했습니다. 앱은 iOS 만 사용합니다
    ],
    products: [
        .library(name: "Core_Domain", targets: ["Core_Domain"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Core_Domain",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "Core_DomainTests",
            dependencies: ["Core_Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
