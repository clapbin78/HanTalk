import Foundation

// MARK: - Repository 프로토콜 (Domain은 구현을 모른다)

public protocol UserRepository: Sendable {
    /// 현재 기기에 등록된 사용자. 미가입이면 nil.
    func currentUser() async throws -> User?
    /// 닉네임 + 전화번호로 가입. 전화번호는 구현체에서 해시 후 서버 전송.
    func register(nickname: String, phoneNumber: String) async throws -> User
}

public protocol FriendRepository: Sendable {
    /// 연락처 목록을 서버 가입자와 대조해 친구 후보 반환. (아직 등록 아님)
    func findCandidates(in contacts: [DeviceContact]) async throws -> [FriendCandidate]
    /// 후보를 친구로 등록.
    func addFriends(_ candidates: [FriendCandidate]) async throws -> [Friend]
    func friends() async throws -> [Friend]
    func removeFriend(id: String) async throws
}

public protocol ChatRoomRepository: Sendable {
    /// 1:1 방은 같은 상대와 중복 생성하지 않고 기존 방을 반환.
    func createRoom(kind: ChatRoom.Kind, name: String?, memberIDs: [String]) async throws -> ChatRoom
    func rooms() async throws -> [ChatRoom]
    func room(id: String) async throws -> ChatRoom?
    /// 방 목록 변경 스트림 (새 메시지 도착으로 인한 미리보기 갱신 포함).
    func observeRooms() -> AsyncStream<[ChatRoom]>
}

public protocol MessageRepository: Sendable {
    /// 로컬 저장(즉시 표시) → 서버 업로드 순서로 처리.
    @discardableResult
    func send(_ draft: MessageDraft, roomID: String) async throws -> Message
    func messages(roomID: String) async throws -> [Message]
    /// 해당 방 메시지 변경 스트림.
    func observeMessages(roomID: String) -> AsyncStream<[Message]>
    /// 보관 정책에 따라 만료 메시지 삭제. 삭제한 개수 반환.
    @discardableResult
    func purgeExpired(policy: RetentionPolicy) async throws -> Int
}
