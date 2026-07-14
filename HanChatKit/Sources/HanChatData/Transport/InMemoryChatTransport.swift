import Foundation
import HanChatCore

/// 서버 없이 돌아가는 데모/테스트용 트랜스포트.
/// - 가짜 가입자를 심어 연락처 매칭을 시뮬레이션한다.
/// - 데모 봇에게 메시지를 보내면 잠시 후 답장이 온다 (기기 1대로 수신 흐름 테스트).
public actor InMemoryChatTransport: ChatTransport {
    private var registeredUsers: [String: RemoteUser] = [:]   // phoneHash → user
    private var mailboxes: [String: [TransportEnvelope]] = [:] // userID → envelopes
    private var listeners: [String: AsyncStream<TransportEnvelope>.Continuation] = [:]
    private let botEnabled: Bool

    public static let botID = "hanchat-demo-bot"

    public init(seedFakeUsers: [(nickname: String, phoneNumber: String)] = [], botEnabled: Bool = true) {
        self.botEnabled = botEnabled
        for (index, seed) in seedFakeUsers.enumerated() {
            let hash = PhoneNumberHasher.hash(seed.phoneNumber)
            registeredUsers[hash] = RemoteUser(
                id: "demo-user-\(index)",
                nickname: seed.nickname,
                phoneNumberHash: hash
            )
        }
        if botEnabled {
            let botHash = PhoneNumberHasher.hash("010-0000-0000")
            registeredUsers[botHash] = RemoteUser(
                id: Self.botID, nickname: "한톡봇 🤖", phoneNumberHash: botHash
            )
        }
    }

    public func register(user: User) async throws {
        registeredUsers[user.phoneNumberHash] = RemoteUser(
            id: user.id, nickname: user.nickname, phoneNumberHash: user.phoneNumberHash
        )
    }

    public func lookup(phoneNumberHashes: [String]) async throws -> [RemoteUser] {
        var result = phoneNumberHashes.compactMap { registeredUsers[$0] }
        // 데모 봇은 항상 후보에 포함
        if botEnabled, let bot = registeredUsers.values.first(where: { $0.id == Self.botID }),
           !result.contains(bot) {
            result.append(bot)
        }
        return result
    }

    public func send(_ envelope: TransportEnvelope, to recipientIDs: [String]) async throws {
        for recipient in recipientIDs {
            deliver(envelope, to: recipient)
        }
        // 봇에게 보냈으면 1초 뒤 답장
        if botEnabled, recipientIDs.contains(Self.botID) {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1))
                await self?.botReply(to: envelope)
            }
        }
    }

    public func incoming(for userID: String) -> AsyncStream<TransportEnvelope> {
        let (stream, continuation) = AsyncStream<TransportEnvelope>.makeStream()
        listeners[userID] = continuation
        // 밀린 봉투 전달
        for envelope in mailboxes[userID, default: []] {
            continuation.yield(envelope)
        }
        return stream
    }

    public func acknowledge(envelopeID: String, for userID: String) async throws {
        mailboxes[userID, default: []].removeAll { $0.id == envelopeID }
    }

    // MARK: Private

    private func deliver(_ envelope: TransportEnvelope, to recipient: String) {
        mailboxes[recipient, default: []].append(envelope)
        listeners[recipient]?.yield(envelope)
    }

    private func botReply(to envelope: TransportEnvelope) {
        let replyText: String
        switch envelope.message.content {
        case .text(let text):
            replyText = "\"\(text)\" 잘 받았어요! 저는 데모 봇이라 24시간 뒤면 이 대화도 사라져요 ⏳"
        case .drawing:
            replyText = "그림 멋진데요? 🎨 획이 벡터로 재생되는 거 보셨나요?"
        }
        let bot = User(
            id: Self.botID,
            nickname: "한톡봇 🤖",
            phoneNumberHash: PhoneNumberHasher.hash("010-0000-0000")
        )
        let reply = Message(
            roomID: envelope.room.id,
            senderID: bot.id,
            content: .text(replyText),
            deliveryState: .sent
        )
        deliver(
            TransportEnvelope(message: reply, room: envelope.room, sender: bot),
            to: envelope.sender.id
        )
    }
}
