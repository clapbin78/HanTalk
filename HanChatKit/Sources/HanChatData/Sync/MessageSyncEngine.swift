import Foundation
import HanChatCore

/// 수신 파이프라인: 우편함 구독 → 로컬 저장 → 서버 봉투 삭제(ack).
/// ack가 곧 "서버에서 내용 삭제"이므로, 정상 흐름에서 서버엔 아무것도 남지 않는다.
final class MessageSyncEngine: @unchecked Sendable {
    private let store: LocalStore
    private let transport: any ChatTransport
    private let notifier: ChangeNotifier
    private var task: Task<Void, Never>?

    init(store: LocalStore, transport: any ChatTransport, notifier: ChangeNotifier) {
        self.store = store
        self.transport = transport
        self.notifier = notifier
    }

    func start(userID: String) {
        guard task == nil else { return }
        task = Task { [store, transport, notifier] in
            for await envelope in await transport.incoming(for: userID) {
                do {
                    // 방이 없으면 생성 (초대받은 단톡방, 새 1:1 등)
                    try await store.upsertRoom(envelope.room)

                    // 모르는 발신자면 닉네임만 임시 친구로 저장 (표시용)
                    let knownIDs = Set(try await store.friends().map(\.id))
                    if !knownIDs.contains(envelope.sender.id) {
                        try await store.upsertFriends([
                            Friend(id: envelope.sender.id, nickname: envelope.sender.nickname)
                        ])
                        await notifier.notify("friends")
                    }

                    var message = envelope.message
                    message.deliveryState = .delivered
                    try await store.insertMessage(message)
                    try await store.updateRoomPreview(
                        roomID: message.roomID,
                        preview: message.content.preview,
                        at: message.sentAt
                    )
                    await notifier.notify("messages:\(message.roomID)")
                    await notifier.notify("rooms")

                    // 수신 완료 → 서버에서 즉시 삭제
                    try await transport.acknowledge(envelopeID: envelope.id, for: userID)
                } catch {
                    // 저장 실패 시 ack하지 않음 → 서버에 남아 다음 접속 때 재전달됨
                    continue
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
