import 'package:flutter/foundation.dart';

/// 관리자 모드 세션 (앱 실행 동안만 메모리 유지 — 재시작하면 해제).
/// 관리자 토큰은 Cloud Function이 발급한 것으로, 관리자 API 호출 시 함께 보낸다.
/// 관리자 기능이 늘어나도 이 토큰 하나로 게이트한다.
class AdminSession extends ChangeNotifier {
  static final AdminSession instance = AdminSession._();
  AdminSession._();

  String? _token;

  bool get isAdmin => _token != null;
  String? get token => _token;

  void enter(String token) {
    _token = token;
    notifyListeners();
  }

  void exit() {
    _token = null;
    notifyListeners();
  }
}
