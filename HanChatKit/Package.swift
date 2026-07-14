// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HanChatKit",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17)],
    products: [
        // 순수 도메인 — 어떤 플랫폼에서도 컴파일되는 코어
        .library(name: "HanChatCore", targets: ["HanChatCore"]),
        // 로컬(SwiftData) 저장 + Repository 구현
        .library(name: "HanChatData", targets: ["HanChatData"]),
        // Firebase 백엔드 어댑터 (교체 가능)
        .library(name: "HanChatFirebase", targets: ["HanChatFirebase"]),
        // 완성형 채팅 UI (SwiftUI + UIKit 래퍼)
        .library(name: "HanChatUI", targets: ["HanChatUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "HanChatCore",
            dependencies: [],
            resources: [.process("Resources")]  // 에러 메시지 다국어 카탈로그
        ),
        .target(
            name: "HanChatData",
            dependencies: ["HanChatCore"]
        ),
        .target(
            name: "HanChatFirebase",
            dependencies: [
                "HanChatCore",
                "HanChatData",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
            ]
        ),
        .target(
            name: "HanChatUI",
            dependencies: ["HanChatCore", "HanChatData"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HanChatCoreTests",
            dependencies: ["HanChatCore", "HanChatData"]
        ),
    ]
)
