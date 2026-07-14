import XCTest
@testable import HanChatCore
@testable import HanChatData

final class HanChatCoreTests: XCTestCase {

    // MARK: 전화번호 해시

    func test_전화번호_형식이_달라도_같은_해시() {
        let a = PhoneNumberHasher.hash("010-1234-5678")
        let b = PhoneNumberHasher.hash("01012345678")
        let c = PhoneNumberHasher.hash("+82 10 1234 5678")
        XCTAssertEqual(a, b)
        XCTAssertEqual(b, c)
    }

    func test_다른_번호는_다른_해시() {
        XCTAssertNotEqual(
            PhoneNumberHasher.hash("010-1111-1111"),
            PhoneNumberHasher.hash("010-2222-2222")
        )
    }

    // MARK: 보관 정책

    func test_24시간_정책_만료기준() {
        let cutoff = RetentionPolicy.oneDay.expirationCutoff(now: Date(timeIntervalSince1970: 100_000))
        XCTAssertEqual(cutoff, Date(timeIntervalSince1970: 100_000 - 86_400))
    }

    func test_영구보관은_만료없음() {
        XCTAssertNil(RetentionPolicy.keepForever.expirationCutoff())
    }

    // MARK: 그림 페이로드

    func test_그림_페이로드_인코딩_왕복() throws {
        let payload = DrawingPayload(
            canvasSize: .init(width: 300, height: 300),
            strokes: [
                Stroke(colorHex: "#FF3B30", width: 4, points: [
                    StrokePoint(x: 0, y: 0, t: 0),
                    StrokePoint(x: 10, y: 12, t: 0.05),
                    StrokePoint(x: 20, y: 30, t: 0.11),
                ])
            ]
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(DrawingPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.totalDuration, 0.11, accuracy: 0.001)
        // 벡터 포맷이 정말 가벼운지: 점 3개짜리 획 = 수백 바이트 수준
        XCTAssertLessThan(data.count, 1_000)
    }

    // MARK: 메시지 콘텐츠

    func test_메시지_콘텐츠_미리보기() {
        XCTAssertEqual(Message.Content.text("안녕").preview, "안녕")
        XCTAssertEqual(
            Message.Content.drawing(DrawingPayload(canvasSize: .init(width: 1, height: 1), strokes: [])).preview,
            "🎨 그림"
        )
    }

    // MARK: 인메모리 트랜스포트 (우체통 동작)

    func test_우체통_전달과_ack() async throws {
        let transport = InMemoryChatTransport(botEnabled: false)
        let sender = User(nickname: "보낸이", phoneNumberHash: "hashA")
        let recipient = User(nickname: "받는이", phoneNumberHash: "hashB")
        try await transport.register(user: sender)
        try await transport.register(user: recipient)

        let room = ChatRoom(kind: .direct, memberIDs: [sender.id, recipient.id])
        let message = Message(roomID: room.id, senderID: sender.id, content: .text("테스트"))
        let envelope = TransportEnvelope(message: message, room: room, sender: sender)

        try await transport.send(envelope, to: [recipient.id])

        var received: TransportEnvelope?
        for await incoming in await transport.incoming(for: recipient.id) {
            received = incoming
            break
        }
        XCTAssertEqual(received?.message.id, message.id)

        // ack = 서버(우체통)에서 삭제
        try await transport.acknowledge(envelopeID: message.id, for: recipient.id)
    }
}
