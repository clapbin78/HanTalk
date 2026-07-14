import 'package:shared_preferences/shared_preferences.dart';

/// 읽음표시 설정 (기본 꺼짐 — opt-in).
/// 켠 사람만 읽음 신호를 보내고, 켠 사람만 상대의 읽음을 표시받는다 → 상호(mutual).
class ReadReceiptSetting {
  static const _key = 'hanchat.readReceiptsEnabled';

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}
