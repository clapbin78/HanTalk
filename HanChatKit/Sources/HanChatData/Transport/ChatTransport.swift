import Foundation
import HanChatCore

/// 서버로 조회된 가입 사용자 (친구 매칭 결과).
public struct RemoteUser: Codable, Hashable, Sendable {
    public let id: String
    public var nickname: String
    public var phoneNumberHash: String

    public init(id: String, nickname: String, phoneNumberHash: String) {
        self.id = id
        self.nickname = nickname
        self.phoneNumberHash = phoneNumberHash
    }
}

/// 우체통에 들어가는 봉투. 수신자가 방을 모를 수 있으므로 방 메타와 발신자 정보를 함께 담는다.
public struct TransportEnvelope: Codable, Sendable, Identifiable {
    public var message: Message
    public var room: ChatRoom
    public var sender: User

    public var id: String { message.id }

    public init(message: Message, room: ChatRoom, sender: User) {
        self.message = message
        self.room = room
        self.sender = sender
    }
}

/// 서버 측 메시지 보관 정책.
///
/// 한톡 앱은 `.ephemeral`이 기본이지만, HanChatKit을 붙이는 다른 앱은
/// 일반 메신저처럼 `.retain(days:)`로 며칠 보관할 수 있다.
/// ⚠️ retain 모드를 쓰면 그 앱의 개인정보처리방침에 "서버 보관 기간"을 반드시 반영할 것.
public enum ServerRetention: Sendable {
    /// 우체통 모드: 전달 확인 즉시 서버에서 삭제 + 미수신분은 24시간 후 삭제
    case ephemeral
    /// 일반 메신저 모드: 전달 여부와 무관하게 n일간 서버 보관 후 삭제
    case retain(days: Int)

    public var ttl: TimeInterval {
        switch self {
        case .ephemeral: return 24 * 60 * 60
        case .retain(let days): return TimeInterval(days) * 24 * 60 * 60
        }
    }

    public var deletesOnAcknowledge: Bool {
        if case .ephemeral = self { return true }
        return false
    }
}

/// 백엔드 추상화. Firebase든 자체 서버든 이 프로토콜만 구현하면 붙는다.
///
/// 서버는 DB가 아니라 **우체통**이다:
/// - `send`: 수신자별 우편함에 봉투를 넣는다.
/// - `incoming`: 내 우편함을 구독한다.
/// - `acknowledge`: 수신 완료 → 서버에서 봉투 즉시 삭제.
/// - 미수신 봉투는 서버 측 스케줄러가 24시간 후 일괄 삭제한다.
public protocol ChatTransport: Sendable {
    func register(user: User) async throws
    /// 전화번호 해시로 가입자 조회. 원본 번호는 절대 서버로 가지 않는다.
    func lookup(phoneNumberHashes: [String]) async throws -> [RemoteUser]
    func send(_ envelope: TransportEnvelope, to recipientIDs: [String]) async throws
    func incoming(for userID: String) async -> AsyncStream<TransportEnvelope>
    func acknowledge(envelopeID: String, for userID: String) async throws
}
