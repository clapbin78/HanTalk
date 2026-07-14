import Foundation
import HanChatCore

/// AI 스텁 — 실제 AI 호출 없이 고정 응답을 돌려준다.
/// Phase 4(수익화 이후)에 OpenAI/Claude API 구현(미국 리전)으로 교체하고
/// aiAssistantEnabled 플래그만 켜면 된다. 테스트가 이 계약을 상시 검증한다.
public struct StubAIAssistantService: AIAssistantService {

    public init() {}

    public func suggestReplies(context: [Message], languageCode: String) async throws -> [String] {
        // 실제 구현에서는 context를 프롬프트로 만들어 languageCode 언어로 생성한다.
        // 스텁은 고정 응답 (실 AI는 사용자 언어로 답하므로 별도 번역 불필요).
        ["👍", "OK!", "😊"]
    }
}

/// 번역 스텁 — 테스트/데모용. Phase 4에서 AI 번역 구현으로 교체 가능.
/// (기본값은 nil → UI가 iOS 18 시스템 온디바이스 번역을 사용)
public struct StubTranslationService: TranslationService {
    public init() {}

    public func translate(_ text: String, to languageCode: String) async throws -> String {
        "[\(languageCode)] \(text)"
    }
}
