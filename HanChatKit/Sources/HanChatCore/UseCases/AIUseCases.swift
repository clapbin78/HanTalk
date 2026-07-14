import Foundation

// MARK: - AI 어시스턴트 (🚩 aiAssistantEnabled 플래그 뒤에 준비된 기능)
//
// 유료 이모티콘과 같은 전략: 구조·로직·테스트는 처음부터 완성해두고
// UI 노출만 막는다. 수익이 생기면 실제 AI 구현(OpenAI/Claude API 등,
// 미국 리전)으로 교체하고 플래그만 켠다.

/// AI 백엔드 추상화. Core는 어떤 AI 제공자인지 모른다.
public protocol AIAssistantService: Sendable {
    /// 최근 대화 맥락으로 답장 후보 생성 (사용자 언어로)
    func suggestReplies(context: [Message], languageCode: String) async throws -> [String]
    /// 수신 메시지 번역 (글로벌 채팅 대비)
    func translate(_ text: String, to languageCode: String) async throws -> String
}

public struct SuggestRepliesUseCase: Sendable {
    let ai: any AIAssistantService
    /// HanChatConfiguration.aiAssistantEnabled 주입
    let enabled: Bool

    public init(ai: any AIAssistantService, enabled: Bool) {
        self.ai = ai
        self.enabled = enabled
    }

    public func callAsFunction(
        context: [Message],
        languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) async throws -> [String] {
        guard enabled else { throw HanChatError.featureDisabled }
        guard !context.isEmpty else { return [] }
        // 최근 10개만 전달 — 토큰(비용) 절약
        return try await ai.suggestReplies(context: Array(context.suffix(10)), languageCode: languageCode)
    }
}

public struct TranslateMessageUseCase: Sendable {
    let ai: any AIAssistantService
    let enabled: Bool

    public init(ai: any AIAssistantService, enabled: Bool) {
        self.ai = ai
        self.enabled = enabled
    }

    public func callAsFunction(
        _ text: String,
        to languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    ) async throws -> String {
        guard enabled else { throw HanChatError.featureDisabled }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        return try await ai.translate(trimmed, to: languageCode)
    }
}
