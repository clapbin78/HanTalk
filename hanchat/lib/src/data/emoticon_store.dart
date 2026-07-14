import 'dart:math' as math;

import '../core/entities.dart';
import '../core/repositories.dart';

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

/// 번역 스텁 — 테스트용 (실제 기본값은 UI의 ML Kit 온디바이스 번역).
class StubTranslationService implements TranslationService {
  const StubTranslationService();

  @override
  Future<String> translate(String text, {required String toLanguage}) async =>
      '[$toLanguage] $text';
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
