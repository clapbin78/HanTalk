import 'package:shared_preferences/shared_preferences.dart';

import '../core/retention.dart';

/// 사용자별 '사라지는 메시지' 설정 (기기 로컬 저장).
///
/// 서버는 어떤 옵션에서도 메시지를 보관하지 않는다(우체통 — ack 즉시 삭제).
/// 이 설정은 오직 '내 기기'에서 메시지를 언제 지울지만 결정한다.
/// - off : 계속 보관 (기본, 일반 메신저처럼)
/// - h24 : 24시간 뒤 삭제
/// - d7  : 7일 뒤 삭제
///
/// 미설정이면 호스트 앱이 준 기본 정책([HanChatConfig.localRetention])을 따른다.
class RetentionSetting {
  static const _key = 'hanchat.retention';

  static const optionOff = 'off';
  static const option24h = 'h24';
  static const option7d = 'd7';

  static Future<String?> _raw() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  static Future<void> setOption(String option) async =>
      (await SharedPreferences.getInstance()).setString(_key, option);

  /// 저장된 옵션이 있으면 그걸로, 없으면 [fallback](앱 기본)으로 정책 결정.
  /// SharedPreferences가 없는 환경(테스트 등)에서는 fallback으로 안전하게 회귀.
  static Future<RetentionPolicy> resolve(RetentionPolicy fallback) async {
    try {
      switch (await _raw()) {
        case optionOff:
          return const RetentionPolicy.keepForever();
        case option24h:
          return RetentionPolicy.oneDay;
        case option7d:
          return const RetentionPolicy.expireAfterDuration(Duration(days: 7));
        default:
          return fallback;
      }
    } catch (_) {
      return fallback;
    }
  }

  /// 현재 선택된 옵션 키 (UI 표시용). 미설정이면 fallback을 옵션 키로 환산.
  static Future<String> currentOption(RetentionPolicy fallback) async {
    try {
      final raw = await _raw();
      if (raw != null) return raw;
    } catch (_) {/* fallback으로 진행 */}
    final d = fallback.expireAfter;
    if (d == null) return optionOff;
    if (d.inHours <= 24) return option24h;
    return option7d;
  }
}
