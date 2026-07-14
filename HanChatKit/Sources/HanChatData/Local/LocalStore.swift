import Foundation
import SwiftData
import HanChatCore

/// SwiftData 접근 전담 액터. 모든 로컬 읽기/쓰기는 여기를 거친다.
@ModelActor
public actor LocalStore {

    // MARK: User

    func currentUser() throws -> User? {
        try modelContext.fetch(FetchDescriptor<SDUser>()).first?.entity
    }

    func saveUser(_ user: User) throws {
        modelContext.insert(
            SDUser(
                id: user.id,
                nickname: user.nickname,
                phoneNumberHash: user.phoneNumberHash,
                createdAt: user.createdAt
            )
        )
        try modelContext.save()
    }

    // MARK: Friends

    func friends() throws -> [Friend] {
        let descriptor = FetchDescriptor<SDFriend>(sortBy: [SortDescriptor(\.addedAt)])
        return try modelContext.fetch(descriptor).map(\.entity)
    }

    func upsertFriends(_ newFriends: [Friend]) throws {
        let existing = try modelContext.fetch(FetchDescriptor<SDFriend>())
        var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for friend in newFriends {
            if let found = byID[friend.id] {
                found.nickname = friend.nickname
                found.localName = friend.localName ?? found.localName
            } else {
                let model = SDFriend(
                    id: friend.id,
                    nickname: friend.nickname,
                    localName: friend.localName,
                    addedAt: friend.addedAt
                )
                modelContext.insert(model)
                byID[friend.id] = model
            }
        }
        try modelContext.save()
    }

    func removeFriend(id: String) throws {
        try modelContext.delete(model: SDFriend.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    // MARK: Rooms

    func rooms() throws -> [ChatRoom] {
        let descriptor = FetchDescriptor<SDChatRoom>(
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.entity)
    }

    func room(id: String) throws -> ChatRoom? {
        var descriptor = FetchDescriptor<SDChatRoom>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.entity
    }

    /// 같은 멤버 구성의 1:1 방이 있으면 그걸 반환.
    func existingDirectRoom(memberIDs: [String]) throws -> ChatRoom? {
        let sorted = memberIDs.sorted()
        let directRaw = ChatRoom.Kind.direct.rawValue
        let candidates = try modelContext.fetch(
            FetchDescriptor<SDChatRoom>(predicate: #Predicate { $0.kindRaw == directRaw })
        )
        return candidates.first { $0.memberIDs.sorted() == sorted }?.entity
    }

    func upsertRoom(_ room: ChatRoom) throws {
        let roomID = room.id
        var descriptor = FetchDescriptor<SDChatRoom>(predicate: #Predicate { $0.id == roomID })
        descriptor.fetchLimit = 1
        if let found = try modelContext.fetch(descriptor).first {
            found.name = room.name
            found.memberIDs = room.memberIDs
        } else {
            modelContext.insert(SDChatRoom(room: room))
        }
        try modelContext.save()
    }

    func updateRoomPreview(roomID: String, preview: String, at date: Date) throws {
        var descriptor = FetchDescriptor<SDChatRoom>(predicate: #Predicate { $0.id == roomID })
        descriptor.fetchLimit = 1
        guard let found = try modelContext.fetch(descriptor).first else { return }
        found.lastMessagePreview = preview
        found.lastMessageAt = date
        try modelContext.save()
    }

    // MARK: Emoticons (내 보관함 — 기기에만 저장)

    func myEmoticons() throws -> [Emoticon] {
        let descriptor = FetchDescriptor<SDEmoticonItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.entity)
    }

    func hasEmoticon(id: String) throws -> Bool {
        var descriptor = FetchDescriptor<SDEmoticonItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func addEmoticon(_ emoticon: Emoticon) throws {
        guard try !hasEmoticon(id: emoticon.id) else { return }
        modelContext.insert(try SDEmoticonItem(emoticon: emoticon))
        try modelContext.save()
    }

    // MARK: Messages

    func messages(roomID: String) throws -> [Message] {
        let descriptor = FetchDescriptor<SDMessage>(
            predicate: #Predicate { $0.roomID == roomID },
            sortBy: [SortDescriptor(\.sentAt)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.entity)
    }

    func insertMessage(_ message: Message) throws {
        modelContext.insert(try SDMessage(message: message))
        try modelContext.save()
    }

    func updateMessageState(id: String, state: Message.DeliveryState) throws {
        var descriptor = FetchDescriptor<SDMessage>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let found = try modelContext.fetch(descriptor).first else { return }
        found.deliveryStateRaw = state.rawValue
        try modelContext.save()
    }

    /// 만료 메시지 일괄 삭제. 삭제 개수 반환.
    func purgeMessages(olderThan cutoff: Date) throws -> Int {
        let expired = try modelContext.fetch(
            FetchDescriptor<SDMessage>(predicate: #Predicate { $0.sentAt < cutoff })
        )
        expired.forEach { modelContext.delete($0) }
        try modelContext.save()
        return expired.count
    }
}
