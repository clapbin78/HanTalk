import Foundation

public enum HanChatError: LocalizedError, Sendable {
    case notConfigured
    case notRegistered
    case roomNotFound(String)
    case transport(String)
    case storage(String)
    case permissionDenied(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "HanChat.configure(_:)를 먼저 호출해 주세요."
        case .notRegistered:
            return "사용자 등록이 필요합니다."
        case .roomNotFound(let id):
            return "채팅방을 찾을 수 없습니다: \(id)"
        case .transport(let message):
            return "네트워크 오류: \(message)"
        case .storage(let message):
            return "저장소 오류: \(message)"
        case .permissionDenied(let what):
            return "권한이 거부되었습니다: \(what)"
        }
    }
}
