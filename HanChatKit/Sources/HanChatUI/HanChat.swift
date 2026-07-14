import SwiftUI
import HanChatCore
import HanChatData

/// SDK 진입점. 호스트 앱은 이 한 줄이면 된다:
/// ```swift
/// try HanChat.configure(HanChatConfiguration(transport: ..., privacyPolicyURL: ..., termsOfServiceURL: ...))
/// ```
/// 이후 SwiftUI에선 `HanChatRootView()`, UIKit에선 `HanChatViewController()`를 띄운다.
public enum HanChat {
    public private(set) static var client: HanChatClient?

    @discardableResult
    public static func configure(_ configuration: HanChatConfiguration) throws -> HanChatClient {
        let client = try HanChatClient(configuration: configuration)
        self.client = client
        Task { await client.start() }
        return client
    }

    static func requireClient() -> HanChatClient {
        guard let client else {
            fatalError("HanChat.configure(_:)를 앱 시작 시점에 먼저 호출해 주세요.")
        }
        return client
    }
}

/// 테마 (호스트 앱 브랜드에 맞게 오버라이드 가능)
public struct HanChatTheme: Sendable {
    public var accent: Color
    public var myBubble: Color
    public var otherBubble: Color

    public static let `default` = HanChatTheme(
        accent: Color(red: 1.0, green: 0.85, blue: 0.1),
        myBubble: Color(red: 1.0, green: 0.9, blue: 0.3),
        otherBubble: Color(.systemGray5)
    )

    public init(accent: Color, myBubble: Color, otherBubble: Color) {
        self.accent = accent
        self.myBubble = myBubble
        self.otherBubble = otherBubble
    }
}

struct HanChatThemeKey: EnvironmentKey {
    static let defaultValue = HanChatTheme.default
}

extension EnvironmentValues {
    var hanChatTheme: HanChatTheme {
        get { self[HanChatThemeKey.self] }
        set { self[HanChatThemeKey.self] = newValue }
    }
}
