import Foundation

/// 이모티콘 갤러리에 공개된 이모티콘.
///
/// 그림 메시지와 같은 벡터 포맷(DrawingPayload)이라 저장 비용이 수 KB 수준이고,
/// "그리는 과정 재생"이 그대로 움직이는 이모티콘 효과가 된다.
public struct Emoticon: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var creatorID: String
    public var creatorNickname: String
    public var payload: DrawingPayload
    /// 가격(원). 0 = 무료.
    /// 유료 판매는 구조만 만들어두고 `paidEmoticonsEnabled` 플래그로 숨김 (Phase 3에서 노출).
    public var price: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        creatorID: String,
        creatorNickname: String,
        payload: DrawingPayload,
        price: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.creatorID = creatorID
        self.creatorNickname = creatorNickname
        self.payload = payload
        self.price = price
        self.createdAt = createdAt
    }

    public var isFree: Bool { price == 0 }
}

/// 채팅으로 전송되는 이모티콘. 원본 id를 함께 보내
/// 나중에 "사용당 크리에이터 수익" 정산의 근거가 된다.
public struct EmoticonMessage: Codable, Hashable, Sendable {
    public var emoticonID: String
    public var payload: DrawingPayload

    public init(emoticonID: String, payload: DrawingPayload) {
        self.emoticonID = emoticonID
        self.payload = payload
    }
}
