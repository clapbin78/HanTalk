// 임티샵 라이선스 (솔루션 판매 옵션)
//
// 정책:
// - 갤러리 "사용"(둘러보기·받기·채팅 전송)은 모든 앱 기본 포함 — 검증 불필요
// - "업로드/판매"는 유료 옵션 — 서버가 appId로 결제 여부를 확인해야만 UI 노출
// - 클라이언트 플래그를 켜도 서버 확인이 안 되면 절대 노출되지 않는다
//   (진짜 강제는 서버 규칙에서도 이중으로 — firebase/firestore.rules 참고)

/// 서버가 appId로 확인해준 이 앱의 샵 권한.
class ShopEntitlement {
  /// 이모티콘 업로드(및 Phase 3에서 판매) 가능 여부 — 유료 옵션
  final bool uploadEnabled;

  const ShopEntitlement({required this.uploadEnabled});

  /// 확인 실패/미결제 기본값: 사용만 가능, 업로드 불가
  static const none = ShopEntitlement(uploadEnabled: false);
}

/// 라이선스 서버 추상화. hanchat_firebase가 Firestore 구현을 제공한다.
abstract interface class EntitlementService {
  Future<ShopEntitlement> fetch(String appId);
}

/// 앱 시작 후 1회 조회하고 캐시. 서버 오류 시 안전하게 [ShopEntitlement.none].
class GetShopEntitlementUseCase {
  final EntitlementService _service;
  final String _appId;
  ShopEntitlement? _cached;

  GetShopEntitlementUseCase(this._service, {required String appId})
      : _appId = appId;

  Future<ShopEntitlement> call() async {
    if (_cached case final cached?) return cached;
    try {
      return _cached = await _service.fetch(_appId);
    } catch (_) {
      return ShopEntitlement.none; // 실패 시 캐시하지 않음 — 다음에 재시도
    }
  }
}
