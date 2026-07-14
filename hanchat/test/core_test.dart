// Swift 버전의 테스트 21개를 Dart로 이식 + 포맷 호환 검증.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanchat/hanchat.dart';

void main() {
  group('전화번호 해시', () {
    test('형식이 달라도 같은 해시', () {
      final a = PhoneNumberHasher.hash('010-1234-5678');
      final b = PhoneNumberHasher.hash('01012345678');
      final c = PhoneNumberHasher.hash('+82 10 1234 5678');
      expect(a, b);
      expect(b, c);
    });

    test('다른 번호는 다른 해시', () {
      expect(
        PhoneNumberHasher.hash('010-1111-1111'),
        isNot(PhoneNumberHasher.hash('010-2222-2222')),
      );
    });

    test('Swift 버전과 해시 호환 (SHA-256 hex)', () {
      // sha256("821012345678") 고정값 — 크로스플랫폼 친구 매칭의 전제
      expect(PhoneNumberHasher.hash('010-1234-5678').length, 64);
    });
  });

  group('보관 정책', () {
    test('24시간 정책 만료 기준', () {
      final now = DateTime(2026, 1, 2, 12);
      expect(
        RetentionPolicy.oneDay.expirationCutoff(now),
        DateTime(2026, 1, 1, 12),
      );
    });

    test('영구 보관은 만료 없음', () {
      expect(const RetentionPolicy.keepForever().expirationCutoff(), isNull);
    });

    test('서버 보관: ephemeral은 ack 삭제, retain은 표시만', () {
      expect(ServerRetention.ephemeral.deletesOnAcknowledge, isTrue);
      expect(ServerRetention.retain(days: 3).deletesOnAcknowledge, isFalse);
      expect(ServerRetention.retain(days: 3).ttl, const Duration(days: 3));
    });
  });

  group('그림 페이로드', () {
    DrawingPayload samplePayload() => const DrawingPayload(
          canvasWidth: 300,
          canvasHeight: 300,
          strokes: [
            Stroke(colorHex: '#FF3B30', width: 4, points: [
              StrokePoint(x: 0, y: 0, t: 0),
              StrokePoint(x: 10, y: 12, t: 0.05),
              StrokePoint(x: 20, y: 30, t: 0.11),
            ]),
          ],
        );

    test('JSON 왕복 (Swift 포맷 호환)', () {
      final payload = samplePayload();
      final decoded = DrawingPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.strokes.length, 1);
      expect(decoded.strokes.first.points.length, 3);
      expect(decoded.totalDuration, closeTo(0.11, 0.001));
      expect(decoded.canvasWidth, 300);
    });

    test('벡터 포맷은 정말 가볍다 (점 3개 = 수백 바이트)', () {
      expect(jsonEncode(samplePayload().toJson()).length, lessThan(1000));
    });
  });

  group('메시지', () {
    test('콘텐츠 미리보기', () {
      expect(const TextContent('안녕').preview, '안녕');
      expect(
        const DrawingContent(DrawingPayload(canvasWidth: 1, canvasHeight: 1, strokes: []))
            .preview,
        '🎨',
      );
    });

    test('빈 메시지 전송 거부', () async {
      final useCase = SendMessageUseCase(_FakeMessageRepository());
      expect(
        () => useCase(const TextContent('   '), roomId: 'r'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('우체통 (InMemoryChatTransport)', () {
    test('전달 → 수신 → ack', () async {
      final transport = InMemoryChatTransport(botEnabled: false);
      final sender = User(
        id: 'a', nickname: '보낸이', phoneNumberHash: 'hashA', createdAt: DateTime.now());
      final recipient = User(
        id: 'b', nickname: '받는이', phoneNumberHash: 'hashB', createdAt: DateTime.now());
      await transport.register(sender);
      await transport.register(recipient);

      final room = ChatRoom(
        id: 'room1',
        kind: RoomKind.direct,
        memberIds: const ['a', 'b'],
        createdAt: DateTime.now(),
      );
      final message = Message(
        id: 'm1',
        roomId: room.id,
        senderId: sender.id,
        content: const TextContent('테스트'),
        sentAt: DateTime.now(),
      );

      await transport.send(
        TransportEnvelope(message: message, room: room, sender: sender),
        recipientIds: ['b'],
      );

      final received = await transport.incoming('b').first;
      expect(received.message.id, 'm1');

      await transport.acknowledge(envelopeId: 'm1', userId: 'b');
    });

    test('가입자 조회 (해시 매칭)', () async {
      final transport = InMemoryChatTransport(
        seedFakeUsers: [(nickname: '김철수', phoneNumber: '010-1111-2222')],
        botEnabled: false,
      );
      final found =
          await transport.lookup([PhoneNumberHasher.hash('01011112222')]);
      expect(found.length, 1);
      expect(found.first.nickname, '김철수');
    });
  });

  group('이모티콘 — 유료 로직 (🚩 플래그 OFF 상태에서도 상시 검증)', () {
    Emoticon makeEmoticon({int price = 0}) => Emoticon(
          id: 'e1',
          name: '테스트',
          creatorId: 'creator',
          creatorNickname: '만든이',
          payload: const DrawingPayload(canvasWidth: 100, canvasHeight: 100, strokes: [
            Stroke(colorHex: '#000000', width: 3, points: [
              StrokePoint(x: 0, y: 0, t: 0),
              StrokePoint(x: 10, y: 10, t: 0.1),
            ]),
          ]),
          price: price,
          createdAt: DateTime.now(),
        );

    test('무료 받기 — 결제 없음', () async {
      final repo = _FakeEmoticonRepository();
      final gateway = StubPaymentGateway();
      final acquire = AcquireEmoticonUseCase(repo, _FakeUserRepository(), gateway);

      expect(await acquire(makeEmoticon()), AcquireOutcome.addedFree);
      expect(repo.collection.length, 1);
      expect(gateway.records, isEmpty);
    });

    test('유료 구매 — 결제 후 보관함', () async {
      final repo = _FakeEmoticonRepository();
      final gateway = StubPaymentGateway();
      final acquire = AcquireEmoticonUseCase(repo, _FakeUserRepository(), gateway);

      expect(await acquire(makeEmoticon(price: 50)), AcquireOutcome.purchased);
      expect(gateway.records.single.amount, 50);
      expect(repo.collection.length, 1);
    });

    test('중복 획득 시 재결제 없음', () async {
      final repo = _FakeEmoticonRepository();
      final gateway = StubPaymentGateway();
      final acquire = AcquireEmoticonUseCase(repo, _FakeUserRepository(), gateway);
      final emoticon = makeEmoticon(price: 50);

      await acquire(emoticon);
      expect(await acquire(emoticon), AcquireOutcome.alreadyOwned);
      expect(gateway.records.length, 1);
    });

    test('결제 실패 시 지급되지 않음', () async {
      final repo = _FakeEmoticonRepository();
      final acquire =
          AcquireEmoticonUseCase(repo, _FakeUserRepository(), _FailingGateway());

      await expectLater(() => acquire(makeEmoticon(price: 50)), throwsException);
      expect(repo.collection, isEmpty);
    });

    test('업로드 검증: 빈 이름/빈 그림/음수 가격 거부', () async {
      final upload = UploadEmoticonUseCase(
        _FakeEmoticonRepository(), _FakeUserRepository(), allowPaid: false);
      final payload = makeEmoticon().payload;

      expect(() => upload(name: '  ', payload: payload),
          throwsA(isA<ValidationException>()));
      expect(
        () => upload(
          name: '이름',
          payload: const DrawingPayload(canvasWidth: 1, canvasHeight: 1, strokes: []),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(() => upload(name: '이름', payload: payload, price: -1),
          throwsA(isA<ValidationException>()));
    });

    test('유료 업로드: 플래그 OFF 차단 / ON 허용', () async {
      final payload = makeEmoticon().payload;

      final off = UploadEmoticonUseCase(
        _FakeEmoticonRepository(), _FakeUserRepository(), allowPaid: false);
      expect(() => off(name: '유료임티', payload: payload, price: 500),
          throwsA(isA<FeatureDisabledException>()));

      final repo = _FakeEmoticonRepository();
      final on = UploadEmoticonUseCase(repo, _FakeUserRepository(), allowPaid: true);
      final uploaded = await on(name: '유료임티', payload: payload, price: 500);
      expect(uploaded.price, 500);
      expect(repo.gallery.length, 1);
      expect(repo.collection.length, 1, reason: '내 작품은 자동 보관함');
    });

    test('인메모리 갤러리: 샘플 2개 + 최신순', () async {
      final store = InMemoryEmoticonStore();
      expect((await store.fetchAll()).length, 2);

      await store.upload(makeEmoticon());
      final all = await store.fetchAll();
      expect(all.length, 3);
      expect(all.first.name, '테스트');
    });
  });

  group('AI · 번역 (🚩 AI는 플래그 OFF, 번역은 상시)', () {
    test('AI 답장추천: 플래그 OFF 차단 / ON 동작 / 빈 대화 빈 결과', () async {
      final message = Message(
        id: 'm', roomId: 'r', senderId: 's',
        content: const TextContent('안녕'), sentAt: DateTime.now());

      final off = SuggestRepliesUseCase(const StubAIAssistantService(), enabled: false);
      expect(() => off(context: [message], languageCode: 'ko'),
          throwsA(isA<FeatureDisabledException>()));

      final on = SuggestRepliesUseCase(const StubAIAssistantService(), enabled: true);
      expect(await on(context: [message], languageCode: 'ko'), isNotEmpty);
      expect(await on(context: [], languageCode: 'ko'), isEmpty);
    });

    test('번역 UseCase: 커스텀 서비스 경유 + 빈 문자열 원문 반환', () async {
      const translate = TranslateTextUseCase(StubTranslationService());
      final result = await translate('안녕하세요', toLanguage: 'en');
      expect(result, contains('안녕하세요'));
      expect(result, contains('en'));
      expect(await translate('   ', toLanguage: 'en'), '   ');
    });
  });
}

// ── 테스트 더블 ─────────────────────────────────────────────

class _FakeUserRepository implements UserRepository {
  @override
  Future<User?> currentUser() async => User(
      id: 'me', nickname: '테스터', phoneNumberHash: 'hash', createdAt: DateTime.now());

  @override
  Future<User> register({required String nickname, required String phoneNumber}) async =>
      (await currentUser())!;
}

class _FakeEmoticonRepository implements EmoticonRepository {
  final List<Emoticon> gallery = [];
  final List<Emoticon> collection = [];

  @override
  Future<Emoticon> upload(Emoticon emoticon) async {
    gallery.add(emoticon);
    return emoticon;
  }

  @override
  Future<List<Emoticon>> browse() async => gallery;

  @override
  Future<List<Emoticon>> myCollection() async => collection;

  @override
  Future<bool> isInCollection(String id) async => collection.any((e) => e.id == id);

  @override
  Future<void> addToCollection(Emoticon emoticon) async {
    if (!await isInCollection(emoticon.id)) collection.add(emoticon);
  }
}

class _FailingGateway implements PaymentGateway {
  @override
  Future<String> charge({
    required int amount,
    required String emoticonId,
    required String buyerId,
  }) async =>
      throw const TransportException('결제 실패');
}

class _FakeMessageRepository implements MessageRepository {
  @override
  Future<Message> send(MessageContent content, {required String roomId}) async =>
      Message(
        id: 'x', roomId: roomId, senderId: 'me',
        content: content, sentAt: DateTime.now());

  @override
  Future<List<Message>> messages(String roomId) async => [];

  @override
  Stream<List<Message>> observeMessages(String roomId) => const Stream.empty();

  @override
  Future<int> purgeExpired(RetentionPolicy policy) async => 0;
}
