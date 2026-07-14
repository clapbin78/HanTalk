import Foundation
import SwiftData
import HanChatCore

// MARK: - SwiftData 영속 모델 (Data 레이어 내부 전용 — Domain 엔티티와 분리)

@Model
public final class SDUser {
    @Attribute(.unique) public var id: String
    public var nickname: String
    public var phoneNumberHash: String
    public var createdAt: Date

    public init(id: String, nickname: String, phoneNumberHash: String, createdAt: Date) {
        self.id = id
        self.nickname = nickname
        self.phoneNumberHash = phoneNumberHash
        self.createdAt = createdAt
    }

    var entity: User {
        User(id: id, nickname: nickname, phoneNumberHash: phoneNumberHash, createdAt: createdAt)
    }
}

@Model
public final class SDFriend {
    @Attribute(.unique) public var id: String
    public var nickname: String
    public var localName: String?
    public var addedAt: Date

    public init(id: String, nickname: String, localName: String?, addedAt: Date) {
        self.id = id
        self.nickname = nickname
        self.localName = localName
        self.addedAt = addedAt
    }

    var entity: Friend {
        Friend(id: id, nickname: nickname, localName: localName, addedAt: addedAt)
    }
}

@Model
public final class SDChatRoom {
    @Attribute(.unique) public var id: String
    public var kindRaw: String
    public var name: String?
    public var memberIDs: [String]
    public var createdAt: Date
    public var lastMessagePreview: String?
    public var lastMessageAt: Date?

    public init(room: ChatRoom) {
        self.id = room.id
        self.kindRaw = room.kind.rawValue
        self.name = room.name
        self.memberIDs = room.memberIDs
        self.createdAt = room.createdAt
        self.lastMessagePreview = room.lastMessagePreview
        self.lastMessageAt = room.lastMessageAt
    }

    var entity: ChatRoom {
        ChatRoom(
            id: id,
            kind: ChatRoom.Kind(rawValue: kindRaw) ?? .direct,
            name: name,
            memberIDs: memberIDs,
            createdAt: createdAt,
            lastMessagePreview: lastMessagePreview,
            lastMessageAt: lastMessageAt
        )
    }
}

@Model
public final class SDMessage {
    @Attribute(.unique) public var id: String
    public var roomID: String
    public var senderID: String
    /// Message.Content를 JSON으로 직렬화 (텍스트/그림 공용)
    public var contentData: Data
    public var sentAt: Date
    public var deliveryStateRaw: String

    public init(message: Message) throws {
        self.id = message.id
        self.roomID = message.roomID
        self.senderID = message.senderID
        self.contentData = try JSONEncoder().encode(message.content)
        self.sentAt = message.sentAt
        self.deliveryStateRaw = message.deliveryState.rawValue
    }

    var entity: Message? {
        guard let content = try? JSONDecoder().decode(Message.Content.self, from: contentData) else {
            return nil
        }
        return Message(
            id: id,
            roomID: roomID,
            senderID: senderID,
            content: content,
            sentAt: sentAt,
            deliveryState: Message.DeliveryState(rawValue: deliveryStateRaw) ?? .sent
        )
    }
}

@Model
public final class SDEmoticonItem {
    @Attribute(.unique) public var id: String
    public var name: String
    public var creatorID: String
    public var creatorNickname: String
    public var payloadData: Data
    public var price: Int
    public var createdAt: Date
    public var addedAt: Date

    public init(emoticon: Emoticon, addedAt: Date = .now) throws {
        self.id = emoticon.id
        self.name = emoticon.name
        self.creatorID = emoticon.creatorID
        self.creatorNickname = emoticon.creatorNickname
        self.payloadData = try JSONEncoder().encode(emoticon.payload)
        self.price = emoticon.price
        self.createdAt = emoticon.createdAt
        self.addedAt = addedAt
    }

    var entity: Emoticon? {
        guard let payload = try? JSONDecoder().decode(DrawingPayload.self, from: payloadData) else {
            return nil
        }
        return Emoticon(
            id: id,
            name: name,
            creatorID: creatorID,
            creatorNickname: creatorNickname,
            payload: payload,
            price: price,
            createdAt: createdAt
        )
    }
}

public enum HanChatSchema {
    public static let models: [any PersistentModel.Type] = [
        SDUser.self, SDFriend.self, SDChatRoom.self, SDMessage.self, SDEmoticonItem.self,
    ]

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: SDUser.self, SDFriend.self, SDChatRoom.self, SDMessage.self, SDEmoticonItem.self,
            configurations: config
        )
    }
}
