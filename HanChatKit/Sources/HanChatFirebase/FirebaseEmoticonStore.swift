import Foundation
import FirebaseFirestore
import HanChatCore
import HanChatData

/// EmoticonStore의 Firebase 구현.
///
/// Firestore 구조:
/// ```
/// emoticons/{emoticonID}
///     ├ name, creatorID, creatorNickname, price, createdAt
///     └ payload: 벡터 JSON (수 KB — 문서 한도 1MB에 한참 못 미침)
/// ```
public final class FirebaseEmoticonStore: EmoticonStore, @unchecked Sendable {
    private let db: Firestore

    public init(firestore: Firestore = .firestore()) {
        self.db = firestore
    }

    public func upload(_ emoticon: Emoticon) async throws {
        try await FirebaseChatTransport.signInIfNeeded()
        let payload = try JSONEncoder().encode(emoticon.payload)
        try await db.collection("emoticons").document(emoticon.id).setData([
            "name": emoticon.name,
            "creatorID": emoticon.creatorID,
            "creatorNickname": emoticon.creatorNickname,
            "payload": payload,
            "price": emoticon.price,
            "createdAt": Timestamp(date: emoticon.createdAt),
        ])
    }

    public func fetchAll() async throws -> [Emoticon] {
        try await FirebaseChatTransport.signInIfNeeded()
        let snapshot = try await db.collection("emoticons")
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let creatorID = data["creatorID"] as? String,
                  let creatorNickname = data["creatorNickname"] as? String,
                  let payloadData = data["payload"] as? Data,
                  let payload = try? JSONDecoder().decode(DrawingPayload.self, from: payloadData)
            else { return nil }
            return Emoticon(
                id: doc.documentID,
                name: name,
                creatorID: creatorID,
                creatorNickname: creatorNickname,
                payload: payload,
                price: data["price"] as? Int ?? 0,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now
            )
        }
    }
}
