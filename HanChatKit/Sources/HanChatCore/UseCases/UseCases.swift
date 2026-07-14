import Foundation

// MARK: - UseCase (앱의 유일한 진입 규칙. ViewModel은 UseCase만 호출한다)

public struct RegisterUserUseCase: Sendable {
    let users: any UserRepository
    public init(users: any UserRepository) { self.users = users }

    public func callAsFunction(nickname: String, phoneNumber: String) async throws -> User {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HanChatError.storage("닉네임을 입력해 주세요.") }
        return try await users.register(nickname: trimmed, phoneNumber: phoneNumber)
    }
}

public struct SyncContactsUseCase: Sendable {
    let friends: any FriendRepository
    public init(friends: any FriendRepository) { self.friends = friends }

    /// 1단계: 연락처에서 가입자 후보 찾기.
    public func findCandidates(in contacts: [DeviceContact]) async throws -> [FriendCandidate] {
        try await friends.findCandidates(in: contacts)
    }

    /// 2단계: 등록. mode == .all이면 후보 전체, .manual이면 선택분만 넘긴다.
    @discardableResult
    public func register(_ selection: [FriendCandidate]) async throws -> [Friend] {
        try await friends.addFriends(selection)
    }
}

public struct CreateChatRoomUseCase: Sendable {
    let rooms: any ChatRoomRepository
    public init(rooms: any ChatRoomRepository) { self.rooms = rooms }

    public func direct(with friendID: String, myID: String) async throws -> ChatRoom {
        try await rooms.createRoom(kind: .direct, name: nil, memberIDs: [myID, friendID])
    }

    public func group(name: String, memberIDs: [String]) async throws -> ChatRoom {
        guard memberIDs.count >= 3 else {
            throw HanChatError.storage("단톡방은 3명 이상부터 만들 수 있어요.")
        }
        return try await rooms.createRoom(kind: .group, name: name, memberIDs: memberIDs)
    }
}

public struct SendMessageUseCase: Sendable {
    let messages: any MessageRepository
    public init(messages: any MessageRepository) { self.messages = messages }

    @discardableResult
    public func callAsFunction(_ draft: MessageDraft, roomID: String) async throws -> Message {
        if case .text(let text) = draft,
           text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw HanChatError.storage("빈 메시지는 보낼 수 없어요.")
        }
        return try await messages.send(draft, roomID: roomID)
    }
}

// MARK: 조회/구독 UseCase — View/ViewModel이 Repository를 직접 만지지 않도록 감싼다

public struct GetCurrentUserUseCase: Sendable {
    let users: any UserRepository
    public init(users: any UserRepository) { self.users = users }

    public func callAsFunction() async throws -> User? {
        try await users.currentUser()
    }
}

public struct GetFriendsUseCase: Sendable {
    let friends: any FriendRepository
    public init(friends: any FriendRepository) { self.friends = friends }

    public func callAsFunction() async throws -> [Friend] {
        try await friends.friends()
    }
}

public struct ObserveChatRoomsUseCase: Sendable {
    let rooms: any ChatRoomRepository
    public init(rooms: any ChatRoomRepository) { self.rooms = rooms }

    public func callAsFunction() -> AsyncStream<[ChatRoom]> {
        rooms.observeRooms()
    }
}

public struct ObserveMessagesUseCase: Sendable {
    let messages: any MessageRepository
    public init(messages: any MessageRepository) { self.messages = messages }

    public func callAsFunction(roomID: String) -> AsyncStream<[Message]> {
        messages.observeMessages(roomID: roomID)
    }
}

public struct PurgeExpiredMessagesUseCase: Sendable {
    let messages: any MessageRepository
    let policy: RetentionPolicy
    public init(messages: any MessageRepository, policy: RetentionPolicy) {
        self.messages = messages
        self.policy = policy
    }

    /// 앱 시작/포그라운드 진입 시 호출. 삭제 개수 반환.
    @discardableResult
    public func callAsFunction() async throws -> Int {
        try await messages.purgeExpired(policy: policy)
    }
}
