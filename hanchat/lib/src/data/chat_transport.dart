// 서버는 DB가 아니라 우체통이다:
// - send: 수신자별 우편함에 봉투를 넣는다
// - incoming: 내 우편함을 구독한다
// - acknowledge: 수신 완료 → 서버에서 즉시 삭제(ephemeral) 또는 delivered 표시(retain)
// - 미수신 봉투는 서버 TTL이 삭제한다
import '../core/entities.dart';

/// 서버로 조회된 가입 사용자 (친구 매칭 결과).
class RemoteUser {
  final String id;
  final String nickname;
  final String phoneNumberHash;

  const RemoteUser({
    required this.id,
    required this.nickname,
    required this.phoneNumberHash,
  });
}

/// 우체통 봉투 — 수신자가 방을 모를 수 있으므로 방 메타와 발신자 정보 포함.
class TransportEnvelope {
  final Message message;
  final ChatRoom room;
  final User sender;

  const TransportEnvelope({
    required this.message,
    required this.room,
    required this.sender,
  });

  String get id => message.id;

  Map<String, dynamic> toJson() => {
        'message': message.toJson(),
        'room': room.toJson(),
        'sender': sender.toJson(),
      };

  factory TransportEnvelope.fromJson(Map<String, dynamic> json) => TransportEnvelope(
        message: Message.fromJson(json['message'] as Map<String, dynamic>),
        room: ChatRoom.fromJson(json['room'] as Map<String, dynamic>),
        sender: User.fromJson(json['sender'] as Map<String, dynamic>),
      );
}

/// 백엔드 추상화. Firebase든 자체 서버든 이것만 구현하면 붙는다.
abstract interface class ChatTransport {
  Future<void> register(User user);

  /// 전화번호 해시로 가입자 조회 (원본 번호는 절대 서버로 가지 않음).
  Future<List<RemoteUser>> lookup(List<String> phoneNumberHashes);

  Future<void> send(TransportEnvelope envelope, {required List<String> recipientIds});

  Stream<TransportEnvelope> incoming(String userId);

  Future<void> acknowledge({required String envelopeId, required String userId});
}
