import XCTest
@testable import HanChatCore
@testable import HanChatData

/// AI 어시스턴트 로직 테스트 — UI에서는 숨겨져 있지만(aiAssistantEnabled=false)
/// 계약은 여기서 항상 검증된다. Phase 4에서 실제 AI 구현으로 교체 시 그대로 통과해야 함.
final class AIAssistantTests: XCTestCase {

    private func makeMessage(_ text: String) -> Message {
        Message(roomID: "room", senderID: "sender", content: .text(text))
    }

    func test_플래그_꺼진_동안_AI_답장추천_차단() async {
        let useCase = SuggestRepliesUseCase(ai: StubAIAssistantService(), enabled: false)
        do {
            _ = try await useCase(context: [makeMessage("안녕")])
            XCTFail("플래그가 꺼져 있으면 featureDisabled를 던져야 함")
        } catch let error as HanChatError {
            guard case .featureDisabled = error else {
                return XCTFail("featureDisabled여야 함, got \(error)")
            }
        } catch {
            XCTFail("HanChatError여야 함")
        }
    }

    func test_플래그_켜면_답장후보_반환() async throws {
        let useCase = SuggestRepliesUseCase(ai: StubAIAssistantService(), enabled: true)
        let suggestions = try await useCase(context: [makeMessage("안녕")], languageCode: "ko")
        XCTAssertFalse(suggestions.isEmpty)
    }

    func test_대화가_비어있으면_빈_추천() async throws {
        let useCase = SuggestRepliesUseCase(ai: StubAIAssistantService(), enabled: true)
        let suggestions = try await useCase(context: [])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_번역_플래그_게이트와_동작() async throws {
        let disabled = TranslateMessageUseCase(ai: StubAIAssistantService(), enabled: false)
        do {
            _ = try await disabled("안녕하세요", to: "en")
            XCTFail("차단돼야 함")
        } catch {}

        let enabled = TranslateMessageUseCase(ai: StubAIAssistantService(), enabled: true)
        let result = try await enabled("안녕하세요", to: "en")
        XCTAssertTrue(result.contains("안녕하세요"))
        XCTAssertTrue(result.contains("en"))
    }
}
