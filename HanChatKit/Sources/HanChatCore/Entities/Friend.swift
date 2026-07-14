import Foundation

/// 내 친구 목록에 등록된 상대.
public struct Friend: Identifiable, Codable, Hashable, Sendable {
    public let id: String            // 상대 User.id
    public var nickname: String      // 서버 닉네임
    public var localName: String?    // 내 연락처에 저장된 이름 (우선 표시)
    public var profileImageURL: URL?
    public var addedAt: Date

    public var displayName: String { localName ?? nickname }

    public init(
        id: String,
        nickname: String,
        localName: String? = nil,
        profileImageURL: URL? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.localName = localName
        self.profileImageURL = profileImageURL
        self.addedAt = addedAt
    }
}

/// 기기 연락처에서 읽어온 항목 (도메인 표현 — Contacts 프레임워크 비의존).
public struct DeviceContact: Hashable, Sendable {
    public var name: String
    public var phoneNumbers: [String]

    public init(name: String, phoneNumbers: [String]) {
        self.name = name
        self.phoneNumbers = phoneNumbers
    }
}

/// 연락처 중 서비스 가입자로 확인된 친구 후보.
public struct FriendCandidate: Identifiable, Hashable, Sendable {
    public let id: String            // 상대 User.id
    public var nickname: String
    public var localName: String?    // 연락처상 이름

    public init(id: String, nickname: String, localName: String?) {
        self.id = id
        self.nickname = nickname
        self.localName = localName
    }
}

/// 연락처 동기화 방식.
public enum ContactSyncMode: String, Codable, Sendable {
    /// 가입자로 확인된 연락처를 전부 자동 등록
    case all
    /// 후보 목록에서 사용자가 직접 선택
    case manual
}
