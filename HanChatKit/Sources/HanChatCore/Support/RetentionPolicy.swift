import Foundation

/// 메시지 보관 정책. 로컬(기기)과 서버는 서로 다른 정책을 가진다.
///
/// - 서버: "우체통" 역할만. 전달 확인 즉시 삭제 + 최대 24시간 (Cloud Functions 스케줄러).
/// - 로컬: 앱 설정에 따라 24시간 자동삭제 또는 영구 보관.
public enum RetentionPolicy: Codable, Hashable, Sendable {
    case keepForever
    case expireAfter(TimeInterval)

    /// 24시간 자동삭제 (기본값)
    public static let oneDay = RetentionPolicy.expireAfter(24 * 60 * 60)

    /// 이 정책에서 `now` 기준 만료 기준 시각. keepForever면 nil.
    public func expirationCutoff(now: Date = .now) -> Date? {
        switch self {
        case .keepForever: return nil
        case .expireAfter(let interval): return now.addingTimeInterval(-interval)
        }
    }
}
