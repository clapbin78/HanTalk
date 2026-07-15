import 'package:shared_preferences/shared_preferences.dart';

/// 알림 설정 (기기 로컬 저장).
/// 실제 푸시 발송은 서버(Firebase FCM) 연동 시 이 값을 참조해 결정한다.
/// - 앱 전체 on/off, 진동, 사운드
/// - 방/특정인 음소거: 방 id 집합 (1:1 방을 음소거하면 그 사람만 조용해짐)
class NotificationSetting {
  static const _all = 'hanchat.notif.enabled';
  static const _vibrate = 'hanchat.notif.vibrate';
  static const _sound = 'hanchat.notif.sound';
  static const _mutedRooms = 'hanchat.notif.mutedRooms';

  static Future<bool> notificationsEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_all) ?? true;
  static Future<void> setNotificationsEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_all, value);

  static Future<bool> vibrateEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_vibrate) ?? true;
  static Future<void> setVibrateEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_vibrate, value);

  static Future<bool> soundEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_sound) ?? true;
  static Future<void> setSoundEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_sound, value);

  static Future<Set<String>> mutedRooms() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_mutedRooms)
          ?.toSet() ??
      {};

  static Future<bool> isRoomMuted(String roomId) async =>
      (await mutedRooms()).contains(roomId);

  static Future<void> setRoomMuted(String roomId, bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    final set = prefs.getStringList(_mutedRooms)?.toSet() ?? {};
    muted ? set.add(roomId) : set.remove(roomId);
    await prefs.setStringList(_mutedRooms, set.toList());
  }
}
