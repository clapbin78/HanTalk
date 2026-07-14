/// 메시지 보관 정책. 로컬(기기)과 서버는 서로 다른 정책을 가진다.
///
/// - 서버: "우체통" — 전달 확인 즉시 삭제(ephemeral) 또는 n일 보관(retain)
/// - 로컬: 24시간 자동삭제(기본) 또는 영구 보관
class RetentionPolicy {
  /// null이면 영구 보관.
  final Duration? expireAfter;

  const RetentionPolicy.keepForever() : expireAfter = null;
  const RetentionPolicy.expireAfterDuration(Duration this.expireAfter);

  /// 24시간 자동삭제 (기본값)
  static const oneDay = RetentionPolicy.expireAfterDuration(Duration(hours: 24));

  /// 이 정책에서 now 기준 만료 기준 시각. 영구 보관이면 null.
  DateTime? expirationCutoff([DateTime? now]) {
    final expireAfter = this.expireAfter;
    if (expireAfter == null) return null;
    return (now ?? DateTime.now()).subtract(expireAfter);
  }
}

/// 서버 측 보관 정책.
/// 한톡 앱은 ephemeral 기본, SDK를 붙이는 다른 앱은 retain(days)로 일반 메신저 구성 가능.
/// ⚠️ retain 모드 사용 시 그 앱의 개인정보처리방침에 서버 보관 기간 명시 필수.
class ServerRetention {
  final Duration ttl;
  final bool deletesOnAcknowledge;

  const ServerRetention._(this.ttl, this.deletesOnAcknowledge);

  /// 우체통 모드: ack 즉시 삭제 + 미수신분 24시간 후 삭제
  static const ephemeral = ServerRetention._(Duration(hours: 24), true);

  /// 일반 메신저 모드: n일 보관 (ack 시 delivered 표시만)
  factory ServerRetention.retain({required int days}) =>
      ServerRetention._(Duration(days: days), false);
}
