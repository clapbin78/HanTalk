import Foundation

/// 1:1 또는 그룹 채팅방.
public struct ChatRoom: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case direct   // 1:1
        case group    // 단톡방
    }

    public let id: String
    public var kind: Kind
    /// 그룹방 이름. 1:1은 nil (상대 이름으로 표시).
    public var name: String?
    public var memberIDs: [String]
    public var createdAt: Date
    /// 목록 미리보기용 (로컬에서 갱신).
    public var lastMessagePreview: String?
    public var lastMessageAt: Date?

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        name: String? = nil,
        memberIDs: [String],
        createdAt: Date = .now,
        lastMessagePreview: String? = nil,
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.memberIDs = memberIDs
        self.createdAt = createdAt
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
    }
}
