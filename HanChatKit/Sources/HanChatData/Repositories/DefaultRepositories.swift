import Foundation
import HanChatCore

// MARK: - Repository 구현 (Local 우선 저장 + Transport 업로드)

public final class DefaultUserRepository: UserRepository, @unchecked Sendable {
    private let store: LocalStore
    private let transport: any ChatTransport

    init(store: LocalStore, transport: any ChatTransport) {
        self.store = store
        self.transport = transport
    }

    public func currentUser() async throws -> User? {
        try await store.currentUser()
    }

    public func register(nickname: String, phoneNumber: String) async throws -> User {
        let user = User(nickname: nickname, phoneNumberHash: PhoneNumberHasher.hash(phoneNumber))
        try await transport.register(user: user)
        try await store.saveUser(user)
        return user
    }
}

public final class DefaultFriendRepository: FriendRepository, @unchecked Sendable {
    private let store: LocalStore
    private let transport: any ChatTransport
    private let notifier: ChangeNotifier

    init(store: LocalStore, transport: any ChatTransport, notifier: ChangeNotifier) {
        self.store = store
        self.transport = transport
        self.notifier = notifier
    }

    public func findCandidates(in contacts: [DeviceContact]) async throws -> [FriendCandidate] {
        // 연락처 이름 매핑을 위해 해시 → 이름 사전 구성
        var nameByHash: [String: String] = [:]
        for contact in contacts {
            for number in contact.phoneNumbers {
                nameByHash[PhoneNumberHasher.hash(number)] = contact.name
            }
        }
        guard !nameByHash.isEmpty else { return [] }

        let matched = try await transport.lookup(phoneNumberHashes: Array(nameByHash.keys))
        let alreadyFriends = Set(try await store.friends().map(\.id))
        let myID = try await store.currentUser()?.id

        return matched
            .filter { $0.id != myID && !alreadyFriends.contains($0.id) }
            .map { FriendCandidate(id: $0.id, nickname: $0.nickname, localName: nameByHash[$0.phoneNumberHash]) }
            .sorted { ($0.localName ?? $0.nickname) < ($1.localName ?? $1.nickname) }
    }

    public func addFriends(_ candidates: [FriendCandidate]) async throws -> [Friend] {
        // 친구 목록은 서버에 올리지 않는다 (개인정보 최소화 — 기기에만 저장).
        let newFriends = candidates.map {
            Friend(id: $0.id, nickname: $0.nickname, localName: $0.localName)
        }
        try await store.upsertFriends(newFriends)
        await notifier.notify("friends")
        return newFriends
    }

    public func friends() async throws -> [Friend] {
        try await store.friends()
    }

    public func removeFriend(id: String) async throws {
        try await store.removeFriend(id: id)
        await notifier.notify("friends")
    }
}

public final class DefaultChatRoomRepository: ChatRoomRepository, @unchecked Sendable {
    private let store: LocalStore
    private let notifier: ChangeNotifier

    init(store: LocalStore, notifier: ChangeNotifier) {
        self.store = store
        self.notifier = notifier
    }

    public func createRoom(kind: ChatRoom.Kind, name: String?, memberIDs: [String]) async throws -> ChatRoom {
        if kind == .direct,
           let existing = try await store.existingDirectRoom(memberIDs: memberIDs) {
            return existing
        }
        let room = ChatRoom(kind: kind, name: name, memberIDs: memberIDs)
        try await store.upsertRoom(room)
        await notifier.notify("rooms")
        return room
    }

    public func rooms() async throws -> [ChatRoom] {
        try await store.rooms()
    }

    public func room(id: String) async throws -> ChatRoom? {
        try await store.room(id: id)
    }

    public func observeRooms() -> AsyncStream<[ChatRoom]> {
        let store = self.store
        let notifier = self.notifier
        return AsyncStream { continuation in
            let task = Task {
                for await _ in await notifier.stream(for: "rooms") {
                    if let rooms = try? await store.rooms() {
                        continuation.yield(rooms)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public final class DefaultEmoticonRepository: EmoticonRepository, @unchecked Sendable {
    private let store: LocalStore
    private let gallery: any EmoticonStore
    private let notifier: ChangeNotifier

    init(store: LocalStore, gallery: any EmoticonStore, notifier: ChangeNotifier) {
        self.store = store
        self.gallery = gallery
        self.notifier = notifier
    }

    public func upload(_ emoticon: Emoticon) async throws -> Emoticon {
        try await gallery.upload(emoticon)
        return emoticon
    }

    public func browse() async throws -> [Emoticon] {
        try await gallery.fetchAll()
    }

    public func myCollection() async throws -> [Emoticon] {
        try await store.myEmoticons()
    }

    public func isInCollection(id: String) async throws -> Bool {
        try await store.hasEmoticon(id: id)
    }

    public func addToCollection(_ emoticon: Emoticon) async throws {
        try await store.addEmoticon(emoticon)
        await notifier.notify("emoticons")
    }
}

public final class DefaultMessageRepository: MessageRepository, @unchecked Sendable {
    private let store: LocalStore
    private let transport: any ChatTransport
    private let notifier: ChangeNotifier

    init(store: LocalStore, transport: any ChatTransport, notifier: ChangeNotifier) {
        self.store = store
        self.transport = transport
        self.notifier = notifier
    }

    @discardableResult
    public func send(_ draft: MessageDraft, roomID: String) async throws -> Message {
        guard let me = try await store.currentUser() else { throw HanChatError.notRegistered }
        guard let room = try await store.room(id: roomID) else { throw HanChatError.roomNotFound(roomID) }

        // 1) 로컬에 즉시 저장 → 내 화면에 바로 표시
        var message = Message(roomID: roomID, senderID: me.id, content: draft.content)
        try await store.insertMessage(message)
        try await store.updateRoomPreview(roomID: roomID, preview: message.content.preview, at: message.sentAt)
        await notifier.notify("messages:\(roomID)")
        await notifier.notify("rooms")

        // 2) 서버(우체통)에 업로드 — 나를 제외한 멤버에게 fan-out
        let recipients = room.memberIDs.filter { $0 != me.id }
        do {
            let envelope = TransportEnvelope(message: message, room: room, sender: me)
            try await transport.send(envelope, to: recipients)
            message.deliveryState = .sent
        } catch {
            message.deliveryState = .failed
        }
        try await store.updateMessageState(id: message.id, state: message.deliveryState)
        await notifier.notify("messages:\(roomID)")

        if message.deliveryState == .failed {
            throw HanChatError.transport("send failed")
        }
        return message
    }

    public func messages(roomID: String) async throws -> [Message] {
        try await store.messages(roomID: roomID)
    }

    public func observeMessages(roomID: String) -> AsyncStream<[Message]> {
        let store = self.store
        let notifier = self.notifier
        return AsyncStream { continuation in
            let task = Task {
                for await _ in await notifier.stream(for: "messages:\(roomID)") {
                    if let messages = try? await store.messages(roomID: roomID) {
                        continuation.yield(messages)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @discardableResult
    public func purgeExpired(policy: RetentionPolicy) async throws -> Int {
        guard let cutoff = policy.expirationCutoff() else { return 0 }
        let count = try await store.purgeMessages(olderThan: cutoff)
        if count > 0 {
            await notifier.notify("rooms")
        }
        return count
    }
}
