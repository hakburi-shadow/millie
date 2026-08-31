// swift-tools-version: 6.0
import PackageDescription

// 조합 계층입니다.
//
// 네트워크와 저장소를 어떻게 엮을지는 이 모듈만 압니다 —
// 온라인 호출 → 로컬 저장 → 실패 시 저장된 데이터로 대체(무작위 정렬) → 중복 제거.
// `Core_Networking` 과 `Core_Persistence` 는 서로를 모르고 여기서 처음 만납니다.
//
// 앱 타깃은 `Core_Domain` 과 이 모듈만 링크합니다. 나머지는 전이 의존으로 따라옵니다.
let package = Package(
    name: "Core_Service",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core_Service", targets: ["Core_Service"])
    ],
    dependencies: [
        .package(path: "../Core_Domain"),
        .package(path: "../Core_Networking"),
        .package(path: "../Core_Persistence")
    ],
    targets: [
        .target(
            name: "Core_Service",
            dependencies: [
                "Core_Domain",
                "Core_Networking",
                "Core_Persistence"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "Core_ServiceTests",
            dependencies: ["Core_Service"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
