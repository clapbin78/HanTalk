import Foundation

/// 채팅 메시지.
public struct Message: Identifiable, Codable, Hashable, Sendable {
    public enum Content: Codable, Hashable, Sendable {
        case text(String)
        case drawing(DrawingPayload)
        case emoticon(EmoticonMessage)

        public var preview: String {
            switch self {
            case .text(let text): return text
            case .drawing: return "🎨 그림"
            case .emoticon: return "😊 이모티콘"
            }
        }
    }

    public enum DeliveryState: String, Codable, Sendable {
        case sending    // 로컬 저장됨, 업로드 중
        case sent       // 서버(우체통) 도착
        case delivered  // 상대 기기 도착 → 서버에서 삭제됨
        case failed
    }

    public let id: String
    public let roomID: String
    public let senderID: String
    public var content: Content
    public var sentAt: Date
    public var deliveryState: DeliveryState

    public init(
        id: String = UUID().uuidString,
        roomID: String,
        senderID: String,
        content: Content,
        sentAt: Date = .now,
        deliveryState: DeliveryState = .sending
    ) {
        self.id = id
        self.roomID = roomID
        self.senderID = senderID
        self.content = content
        self.sentAt = sentAt
        self.deliveryState = deliveryState
    }
}

/// 작성 중인 메시지 (아직 id/발신자 미확정).
public enum MessageDraft: Sendable {
    case text(String)
    case drawing(DrawingPayload)
    case emoticon(EmoticonMessage)

    public var content: Message.Content {
        switch self {
        case .text(let t): return .text(t)
        case .drawing(let d): return .drawing(d)
        case .emoticon(let e): return .emoticon(e)
        }
    }
}
