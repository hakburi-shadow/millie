// swift-tools-version: 6.0
import PackageDescription

// 외부 SDK 어댑터 계층입니다.
//
// 이 모듈의 존재 이유는 하나입니다 — realm-swift 에 대한 의존을 여기 한 곳에만 둡니다.
// 다른 모듈은 RealmSwift 를 직접 import 하지 않고 이 모듈을 통해서만 접근합니다.
// 저장 기술을 바꿀 때 손대는 곳이 이 패키지 하나로 좁혀집니다.
let package = Package(
    name: "ThirdParty_Realm",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ThirdParty_Realm", targets: ["ThirdParty_Realm"])
    ],
    dependencies: [
        // 한 저장소에 10.x 와 20.x 태그가 함께 있어 버전을 반드시 명시합니다.
        // 20.x 는 Xcode 26 대응 라인이고, 10.x 는 그 이전 라인입니다.
        .package(url: "https://github.com/realm/realm-swift.git", from: "20.0.5")
    ],
    targets: [
        .target(
            name: "ThirdParty_Realm",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
