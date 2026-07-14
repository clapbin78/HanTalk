import Foundation
import FirebaseAuth
import FirebaseFirestore
import HanChatCore
import HanChatData

/// ChatTransport의 Firebase 구현.
///
/// Firestore 구조 (서버 = 우체통):
/// ```
/// users/{userID}                     ← 닉네임 + 전화번호 해시 (친구 매칭용)
/// mailboxes/{recipientID}/envelopes/{messageID}
///     ├ payload: TransportEnvelope JSON
///     └ expiresAt: 발송 +24h  ← Firestore TTL 정책이 자동 삭제
/// ```
/// 보관 정책 (ServerRetention):
/// - `.ephemeral` (기본): ack 시 봉투 즉시 삭제 → 채팅 내용이 서버에 남지 않음
/// - `.retain(days:)`: 일반 메신저처럼 n일 보관. ack 시 delivered 표시만 하고 TTL이 삭제.
public final class FirebaseChatTransport: ChatTransport, @unchecked Sendable {
    private let db: Firestore
    private let retention: ServerRetention

    public init(firestore: Firestore = .firestore(), retention: ServerRetention = .ephemeral) {
        self.db = firestore
        self.retention = retention
    }

    /// 익명 인증 (전화번호 인증은 Phase 2에서 교체 가능)
    public static func signInIfNeeded() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    // FirebaseAuth.User와의 이름 충돌 방지를 위해 모듈명 명시
    public func register(user: HanChatCore.User) async throws {
        try await Self.signInIfNeeded()
        try await db.collection("users").document(user.id).setData([
            "nickname": user.nickname,
            "phoneNumberHash": user.phoneNumberHash,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    public func lookup(phoneNumberHashes: [String]) async throws -> [RemoteUser] {
        try await Self.signInIfNeeded()
        var results: [RemoteUser] = []
        // Firestore `in` 쿼리는 한 번에 30개 제한 → 청크 분할
        for chunk in phoneNumberHashes.chunked(into: 30) {
            let snapshot = try await db.collection("users")
                .whereField("phoneNumberHash", in: chunk)
                .getDocuments()
            for doc in snapshot.documents {
                let data = doc.data()
                guard let nickname = data["nickname"] as? String,
                      let hash = data["phoneNumberHash"] as? String else { continue }
                results.append(RemoteUser(id: doc.documentID, nickname: nickname, phoneNumberHash: hash))
            }
        }
        return results
    }

    public func send(_ envelope: TransportEnvelope, to recipientIDs: [String]) async throws {
        try await Self.signInIfNeeded()
        let payload = try JSONEncoder().encode(envelope)
        let batch = db.batch()
        for recipient in recipientIDs {
            let ref = db.collection("mailboxes").document(recipient)
                .collection("envelopes").document(envelope.id)
            batch.setData([
                "payload": payload,
                "senderID": envelope.sender.id,
                "delivered": false,
                "createdAt": FieldValue.serverTimestamp(),
                // Firestore TTL 정책 대상 필드 — 콘솔에서 TTL 설정 필요 (firebase/README 참고)
                "expiresAt": Timestamp(date: Date().addingTimeInterval(retention.ttl)),
            ], forDocument: ref)
        }
        try await batch.commit()
    }

    public func incoming(for userID: String) -> AsyncStream<TransportEnvelope> {
        AsyncStream { continuation in
            let listener = db.collection("mailboxes").document(userID)
                .collection("envelopes")
                .whereField("delivered", isEqualTo: false) // retain 모드에서 중복 수신 방지
                .order(by: "createdAt")
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot else { return }
                    for change in snapshot.documentChanges where change.type == .added {
                        guard let payload = change.document.data()["payload"] as? Data,
                              let envelope = try? JSONDecoder().decode(TransportEnvelope.self, from: payload)
                        else { continue }
                        continuation.yield(envelope)
                    }
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    public func acknowledge(envelopeID: String, for userID: String) async throws {
        let ref = db.collection("mailboxes").document(userID)
            .collection("envelopes").document(envelopeID)
        if retention.deletesOnAcknowledge {
            // ephemeral: 서버에서 즉시 삭제
            try await ref.delete()
        } else {
            // retain: 전달 표시만 — TTL(expiresAt)이 만료 시 삭제
            try await ref.updateData([
                "delivered": true,
                "deliveredAt": FieldValue.serverTimestamp(),
            ])
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
