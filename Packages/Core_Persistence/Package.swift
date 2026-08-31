// swift-tools-version: 6.0
import PackageDescription

// 저장 계층입니다.
//
// Realm 은 `ThirdParty_Realm` 어댑터를 통해서만 접근합니다.
// realm-swift 를 직접 의존하지 않는 것이 요점입니다.
let package = Package(
    name: "Core_Persistence",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core_Persistence", targets: ["Core_Persistence"])
    ],
    dependencies: [
        .package(path: "../Core_Domain"),
        .package(path: "../ThirdParty_Realm")
    ],
    targets: [
        .target(
            name: "Core_Persistence",
            dependencies: [
                "Core_Domain",
                "ThirdParty_Realm"
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "Core_PersistenceTests",
            dependencies: ["Core_Persistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
