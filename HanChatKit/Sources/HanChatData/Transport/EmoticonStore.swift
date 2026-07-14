import Foundation
import HanChatCore

/// 이모티콘 갤러리 원격 저장소 추상화.
/// 채팅과 달리 갤러리는 영구 공개 콘텐츠라 서버에 저장된다 (벡터라 수 KB — 비용 미미).
public protocol EmoticonStore: Sendable {
    func upload(_ emoticon: Emoticon) async throws
    func fetchAll() async throws -> [Emoticon]
}

/// 데모/테스트용 인메모리 갤러리. 샘플 이모티콘이 미리 올라가 있다.
public actor InMemoryEmoticonStore: EmoticonStore {
    private var emoticons: [Emoticon]

    public init(seedSamples: Bool = true) {
        emoticons = seedSamples ? Self.samples : []
    }

    public func upload(_ emoticon: Emoticon) async throws {
        emoticons.removeAll { $0.id == emoticon.id }
        emoticons.append(emoticon)
    }

    public func fetchAll() async throws -> [Emoticon] {
        emoticons.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: 샘플 (하트 / 별)

    private static var samples: [Emoticon] {
        [
            Emoticon(
                id: "sample-heart",
                name: "두근두근",
                creatorID: "hanchat-demo-bot",
                creatorNickname: "한톡봇 🤖",
                payload: heartPayload,
                createdAt: Date(timeIntervalSinceNow: -86_400)
            ),
            Emoticon(
                id: "sample-star",
                name: "반짝",
                creatorID: "hanchat-demo-bot",
                creatorNickname: "한톡봇 🤖",
                payload: starPayload,
                createdAt: Date(timeIntervalSinceNow: -43_200)
            ),
        ]
    }

    private static var heartPayload: DrawingPayload {
        // 하트 곡선을 파라메트릭으로 생성
        var points: [StrokePoint] = []
        let steps = 60
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let x = 16 * pow(sin(t), 3)
            let y = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
            points.append(StrokePoint(
                x: 150 + x * 7,
                y: 130 - y * 7,
                t: Double(i) * 0.02
            ))
        }
        return DrawingPayload(
            canvasSize: .init(width: 300, height: 300),
            strokes: [Stroke(colorHex: "#FF3B30", width: 8, points: points)]
        )
    }

    private static var starPayload: DrawingPayload {
        var points: [StrokePoint] = []
        let center = (x: 150.0, y: 155.0)
        let outer = 95.0, inner = 38.0
        for i in 0...10 {
            let angle = -Double.pi / 2 + Double(i) * .pi / 5
            let radius = i.isMultiple(of: 2) ? outer : inner
            points.append(StrokePoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius,
                t: Double(i) * 0.08
            ))
        }
        return DrawingPayload(
            canvasSize: .init(width: 300, height: 300),
            strokes: [Stroke(colorHex: "#FFCC00", width: 8, points: points)]
        )
    }
}

/// 결제 스텁 — 항상 성공하고 기록만 남긴다.
/// Phase 3에서 IAP 코인 차감 구현으로 교체 (UI는 paidEmoticonsEnabled로 숨김 중).
public actor StubPaymentGateway: PaymentGateway {
    public struct Record: Sendable, Equatable {
        public let amount: Int
        public let emoticonID: String
        public let buyerID: String
    }
    public private(set) var records: [Record] = []

    public init() {}

    public func charge(amount: Int, emoticonID: String, buyerID: String) async throws -> String {
        records.append(Record(amount: amount, emoticonID: emoticonID, buyerID: buyerID))
        return "stub-payment-\(UUID().uuidString)"
    }

    public func chargeCount() -> Int { records.count }
}
