import Foundation

public enum HanChatError: LocalizedError, Sendable {
    case notConfigured
    case notRegistered
    case roomNotFound(String)
    case transport(String)
    case storage(String)
    case permissionDenied(String)
    /// 플래그로 숨겨진 기능 접근 (유료 이모티콘, AI 등)
    case featureDisabled

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "HanChat.configure(_:)를 먼저 호출해 주세요." // 개발자용 — 번역 불필요
        case .notRegistered:
            return String(localized: "사용자 등록이 필요해요.", bundle: .module)
        case .roomNotFound:
            return String(localized: "채팅방을 찾을 수 없어요.", bundle: .module)
        case .transport:
            return String(localized: "네트워크 오류가 발생했어요. 다시 시도해 주세요.", bundle: .module)
        case .storage(let message):
            return message // UseCase가 이미 현지화된 문구를 담아서 던진다
        case .permissionDenied(let what):
            return String(localized: "권한이 거부되었어요: \(what)", bundle: .module)
        case .featureDisabled:
            return String(localized: "아직 준비 중인 기능이에요.", bundle: .module)
        }
    }
}
