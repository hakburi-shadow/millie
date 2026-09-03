// swift-tools-version: 6.0
import PackageDescription

// 전송 계층입니다. 다른 모듈에 의존하지 않습니다.
//
// 도메인도 특정 API 도 모르고 시스템 프레임워크만 사용합니다.
// Alamofire 를 쓰지 않고 URLSession 으로 직접 구현했습니다.
//
// TheCatAPI 의 주소와 파라미터, 응답 형식은 `Core_Service` 에 있습니다.
// 그래서 이 모듈은 다른 API 를 쓰는 프로젝트에 그대로 옮겨도 동작합니다.
let package = Package(
    name: "Core_Networking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core_Networking", targets: ["Core_Networking"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Core_Networking",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "Core_NetworkingTests",
            dependencies: ["Core_Networking"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
