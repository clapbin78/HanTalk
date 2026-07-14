import Foundation

/// 서비스에 가입한 사용자.
public struct User: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var nickname: String
    /// 원본 전화번호는 절대 서버로 보내지 않는다. 매칭에는 해시만 사용.
    public var phoneNumberHash: String
    public var profileImageURL: URL?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        nickname: String,
        phoneNumberHash: String,
        profileImageURL: URL? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.nickname = nickname
        self.phoneNumberHash = phoneNumberHash
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
    }
}
