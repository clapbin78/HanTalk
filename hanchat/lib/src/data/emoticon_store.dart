import 'dart:math' as math;

import '../core/entities.dart';
import '../core/entitlement.dart';
import '../core/profile.dart';
import '../core/report.dart';
import '../core/repositories.dart';
import '../core/support_content.dart';

/// 이모티콘 갤러리 원격 저장소 추상화 (영구 공개 콘텐츠 — 벡터라 수 KB, 비용 미미).
abstract interface class EmoticonStore {
  Future<void> upload(Emoticon emoticon);
  Future<List<Emoticon>> fetchAll();
}

/// 데모/테스트용 인메모리 갤러리. 샘플(하트/별)이 미리 올라가 있다.
class InMemoryEmoticonStore implements EmoticonStore {
  final List<Emoticon> _emoticons;

  InMemoryEmoticonStore({bool seedSamples = true})
      : _emoticons = seedSamples ? _samples() : [];

  @override
  Future<void> upload(Emoticon emoticon) async {
    _emoticons.removeWhere((e) => e.id == emoticon.id);
    _emoticons.add(emoticon);
  }

  @override
  Future<List<Emoticon>> fetchAll() async {
    final sorted = List.of(_emoticons)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  static List<Emoticon> _samples() => [
        Emoticon(
          id: 'sample-heart',
          name: '두근두근',
          creatorId: 'hanchat-demo-bot',
          creatorNickname: '한톡봇 🤖',
          payload: _heart(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Emoticon(
          id: 'sample-star',
          name: '반짝',
          creatorId: 'hanchat-demo-bot',
          creatorNickname: '한톡봇 🤖',
          payload: _star(),
          createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        ),
      ];

  static DrawingPayload _heart() {
    const steps = 60;
    final points = <StrokePoint>[
      for (var i = 0; i <= steps; i++)
        () {
          final t = i / steps * 2 * math.pi;
          final x = 16 * math.pow(math.sin(t), 3).toDouble();
          final y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t);
          return StrokePoint(x: 150 + x * 7, y: 130 - y * 7, t: i * 0.02);
        }(),
    ];
    return DrawingPayload(
      canvasWidth: 300,
      canvasHeight: 300,
      strokes: [Stroke(colorHex: '#FF3B30', width: 8, points: points)],
    );
  }

  static DrawingPayload _star() {
    const outer = 95.0, inner = 38.0;
    final points = <StrokePoint>[
      for (var i = 0; i <= 10; i++)
        () {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? outer : inner;
          return StrokePoint(
            x: 150 + math.cos(angle) * radius,
            y: 155 + math.sin(angle) * radius,
            t: i * 0.08,
          );
        }(),
    ];
    return DrawingPayload(
      canvasWidth: 300,
      canvasHeight: 300,
      strokes: [Stroke(colorHex: '#FFCC00', width: 8, points: points)],
    );
  }
}

/// 결제 스텁 — 항상 성공하고 기록만 남긴다 (Phase 3에서 IAP 구현으로 교체).
class StubPaymentGateway implements PaymentGateway {
  final List<({int amount, String emoticonId, String buyerId})> records = [];

  @override
  Future<String> charge({
    required int amount,
    required String emoticonId,
    required String buyerId,
  }) async {
    records.add((amount: amount, emoticonId: emoticonId, buyerId: buyerId));
    return 'stub-payment-${records.length}';
  }
}

/// 라이선스 스텁 — 데모/테스트용.
/// 실서비스는 hanchat_firebase의 서버 구현으로 교체 (appId → 결제 여부 조회).
class StubEntitlementService implements EntitlementService {
  final ShopEntitlement _result;

  const StubEntitlementService({ShopEntitlement result = ShopEntitlement.none})
      : _result = result;

  /// 데모 앱용: 모든 기능 체험 가능
  const StubEntitlementService.fullAccess()
      : _result = const ShopEntitlement(uploadEnabled: true);

  @override
  Future<ShopEntitlement> fetch(String appId) async => _result;
}

/// 번역 스텁 — 테스트용 (실제 기본값은 UI의 ML Kit 온디바이스 번역).
class StubTranslationService implements TranslationService {
  const StubTranslationService();

  @override
  Future<String> translate(String text, {required String toLanguage}) async =>
      '[$toLanguage] $text';
}

/// 공지/FAQ 스텁 — 데모용 샘플. 실서비스는 hanchat_firebase 구현으로 교체.
class StubSupportContentService implements SupportContentService {
  final _posts = <SupportChannel, List<SupportPost>>{
    SupportChannel.announcements: [
      SupportPost(
        id: 'welcome',
        title: '한톡에 오신 걸 환영합니다 🎉',
        body: '24시간 뒤 사라지는 가벼운 대화, 한톡입니다.\n그림도 그려서 보내보세요!',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
    SupportChannel.faq: [
      SupportPost(
        id: 'q-disappear',
        title: '메시지가 왜 사라지나요?',
        body: '한톡의 메시지는 보낸 지 24시간이 지나면 자동으로 사라집니다. 문자 시절의 가벼운 감성을 살렸어요.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
  };

  @override
  Future<int> version(SupportChannel channel) async =>
      _posts[channel]?.length ?? 0;

  @override
  Future<List<SupportPost>> fetch(SupportChannel channel) async =>
      List.of(_posts[channel] ?? const []);

  @override
  Future<void> post(SupportChannel channel, SupportPost post,
      {required String adminToken}) async {
    _posts.putIfAbsent(channel, () => []).insert(0, post);
  }
}

/// 프로필 스텁 — 데모용 인메모리 (로컬 경로를 그대로 "URL"처럼 반환).
/// 실서비스는 hanchat_firebase가 Storage 업로드 + Firestore 조회로 구현.
class InMemoryProfileService implements ProfileService {
  final _profiles = <String, PublicProfile>{};

  InMemoryProfileService({List<PublicProfile> seed = const []}) {
    for (final p in seed) {
      _profiles[p.userId] = p;
    }
  }

  @override
  Future<void> publish({
    required String userId,
    required String nickname,
    String? localProfilePath,
    String? localCoverPath,
    String? statusMessage,
  }) async {
    _profiles[userId] = PublicProfile(
      userId: userId,
      nickname: nickname,
      // 데모에선 로컬 경로를 그대로 사용 (실서비스는 Storage URL)
      profileImageUrl: localProfilePath,
      coverImageUrl: localCoverPath,
      statusMessage: statusMessage,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<PublicProfile?> fetch(String userId) async => _profiles[userId];
}

/// 신고 스텁 — 데모용. 실서비스는 Firebase 구현으로 교체.
/// 관리자 조회/정지는 데모에선 토큰 검사 없이 인메모리로 동작.
class InMemoryReportService implements ReportService {
  final List<Report> received = [];
  final List<Suspension> _suspensions = [];

  @override
  Future<void> submit(Report report) async => received.add(report);

  @override
  Future<List<Report>> list({required String adminToken}) async =>
      List.of(received.reversed);

  @override
  Future<void> suspendUser(
      {required String userId,
      required String reason,
      required String adminToken}) async {
    _suspensions.removeWhere((s) => s.userId == userId);
    _suspensions.add(Suspension(
      userId: userId,
      reason: reason,
      adminId: 'demo-admin',
      suspendedAt: DateTime.now(),
    ));
  }

  @override
  Future<List<Suspension>> suspensions({required String adminToken}) async =>
      List.of(_suspensions.reversed);

  @override
  Future<void> unsuspend(
          {required String userId, required String adminToken}) async =>
      _suspensions.removeWhere((s) => s.userId == userId);
}

/// 관리자 스텁 — 데모용. 실서비스는 Cloud Function 검증으로 교체.
/// (데모에선 'demo-admin' 비번을 받으면 통과 — 실서비스에선 절대 이렇게 하지 않음)
class StubAdminService implements AdminService {
  @override
  Future<String?> unlock(String password) async =>
      password == 'demo-admin' ? 'demo-admin-token' : null;
}

/// AI 스텁 — Phase 4에서 실제 AI API 구현으로 교체.
class StubAIAssistantService implements AIAssistantService {
  const StubAIAssistantService();

  @override
  Future<List<String>> suggestReplies({
    required List<Message> context,
    required String languageCode,
  }) async =>
      const ['👍', 'OK!', '😊'];
}
