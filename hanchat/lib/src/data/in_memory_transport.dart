import 'dart:async';

import '../core/entities.dart';
import 'chat_transport.dart';
import 'phone_number_hasher.dart';

/// 서버 없이 돌아가는 데모/테스트용 트랜스포트.
/// - 가짜 가입자를 심어 연락처 매칭 시뮬레이션
/// - 봇에게 메시지를 보내면 잠시 후 답장 (기기 1대로 수신 흐름 테스트)
class InMemoryChatTransport implements ChatTransport {
  static const botId = 'hanchat-demo-bot';
  static final _botHash = PhoneNumberHasher.hash('010-0000-0000');

  final bool botEnabled;
  final Map<String, RemoteUser> _registeredByHash = {};
  final Map<String, List<TransportEnvelope>> _mailboxes = {};
  final Map<String, StreamController<TransportEnvelope>> _listeners = {};

  InMemoryChatTransport({
    List<({String nickname, String phoneNumber})> seedFakeUsers = const [],
    this.botEnabled = true,
  }) {
    for (final (index, seed) in seedFakeUsers.indexed) {
      final hash = PhoneNumberHasher.hash(seed.phoneNumber);
      _registeredByHash[hash] = RemoteUser(
        id: 'demo-user-$index',
        nickname: seed.nickname,
        phoneNumberHash: hash,
      );
    }
    if (botEnabled) {
      _registeredByHash[_botHash] = const RemoteUser(
        id: botId,
        nickname: '한톡봇 🤖',
        phoneNumberHash: '',
      );
    }
  }

  @override
  Future<void> register(User user) async {
    _registeredByHash[user.phoneNumberHash] = RemoteUser(
      id: user.id,
      nickname: user.nickname,
      phoneNumberHash: user.phoneNumberHash,
    );
  }

  @override
  Future<List<RemoteUser>> lookup(List<String> phoneNumberHashes) async {
    final result = <RemoteUser>[
      for (final hash in phoneNumberHashes)
        if (_registeredByHash[hash] case final user?) user,
    ];
    // 데모 봇은 항상 후보에 포함
    if (botEnabled && !result.any((u) => u.id == botId)) {
      final bot = _registeredByHash[_botHash];
      if (bot != null) result.add(bot);
    }
    return result;
  }

  @override
  Future<void> send(TransportEnvelope envelope, {required List<String> recipientIds}) async {
    for (final recipient in recipientIds) {
      _deliver(envelope, to: recipient);
    }
    if (botEnabled && recipientIds.contains(botId)) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 1)).then((_) => _botReply(envelope)),
      );
    }
  }

  @override
  Stream<TransportEnvelope> incoming(String userId) {
    final controller = _listeners.putIfAbsent(
      userId,
      () => StreamController<TransportEnvelope>.broadcast(),
    );
    // 밀린 봉투 재전달
    final backlog = List.of(_mailboxes[userId] ?? const <TransportEnvelope>[]);
    Future.microtask(() {
      for (final envelope in backlog) {
        controller.add(envelope);
      }
    });
    return controller.stream;
  }

  @override
  Future<void> acknowledge({required String envelopeId, required String userId}) async {
    _mailboxes[userId]?.removeWhere((e) => e.id == envelopeId);
  }

  void _deliver(TransportEnvelope envelope, {required String to}) {
    _mailboxes.putIfAbsent(to, () => []).add(envelope);
    _listeners[to]?.add(envelope);
  }

  void _botReply(TransportEnvelope envelope) {
    final replyText = switch (envelope.message.content) {
      TextContent(text: final t) => '"$t" 잘 받았어요! 저는 데모 봇이라 24시간 뒤면 이 대화도 사라져요 ⏳',
      DrawingContent() => '그림 멋진데요? 🎨 획이 벡터로 재생되는 거 보셨나요?',
      EmoticonContent() => '이모티콘 잘 받았어요! 😆 갤러리에 올리면 다른 사람들도 쓸 수 있어요',
    };
    final bot = User(
      id: botId,
      nickname: '한톡봇 🤖',
      phoneNumberHash: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
    final reply = Message(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      roomId: envelope.room.id,
      senderId: botId,
      content: TextContent(replyText),
      sentAt: DateTime.now(),
      deliveryState: DeliveryState.sent,
    );
    _deliver(
      TransportEnvelope(message: reply, room: envelope.room, sender: bot),
      to: envelope.sender.id,
    );
  }
}
