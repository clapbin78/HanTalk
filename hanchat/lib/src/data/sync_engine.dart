import 'dart:async';

import '../core/entities.dart';
import 'chat_transport.dart';
import 'local_store.dart';
import 'read_receipt_setting.dart';
import 'repositories_impl.dart';

/// 수신 파이프라인: 우편함 구독 → 로컬 저장 → 서버 봉투 삭제(ack).
/// ack가 곧 "서버에서 내용 삭제"이므로, 정상 흐름에서 서버엔 아무것도 남지 않는다.
class MessageSyncEngine {
  final LocalStore _store;
  final ChatTransport _transport;
  final ChangeNotifierBus _notifier;
  StreamSubscription<TransportEnvelope>? _subscription;

  MessageSyncEngine(this._store, this._transport, this._notifier);

  void start(String userId) {
    if (_subscription != null) return;
    _subscription = _transport.incoming(userId).listen((envelope) async {
      try {
        // 차단한 상대의 메시지는 저장하지 않고 서버에서만 지운다
        final senderStatus = await _store.friendStatus(envelope.sender.id);
        if (senderStatus == FriendStatus.blocked) {
          await _transport.acknowledge(envelopeId: envelope.id, userId: userId);
          return;
        }

        // 읽음 신호(제어 메시지): 말풍선으로 저장하지 않고 내 메시지들에 읽음 반영.
        // 내가 읽음표시를 켰을 때만 반영한다 (상호 opt-in).
        if (envelope.message.content case ReadReceiptContent(messageIds: final ids)) {
          if (await ReadReceiptSetting.isEnabled()) {
            await _store.markRead(ids, envelope.sender.id);
            _notifier.notify('messages:${envelope.message.roomId}');
          }
          await _transport.acknowledge(envelopeId: envelope.id, userId: userId);
          return;
        }

        // 방이 없으면 생성 (초대받은 단톡방, 새 1:1 등)
        await _store.upsertRoom(envelope.room);

        // 모르는 발신자면 닉네임만 임시 친구로 저장 (표시용)
        final knownIds = {for (final f in await _store.friends()) f.id};
        if (!knownIds.contains(envelope.sender.id)) {
          await _store.upsertFriends([
            Friend(
              id: envelope.sender.id,
              nickname: envelope.sender.nickname,
              addedAt: DateTime.now(),
            ),
          ]);
          _notifier.notify('friends');
        }

        final message = envelope.message.copyWith(deliveryState: DeliveryState.delivered);
        await _store.insertMessage(message);
        await _store.updateRoomPreview(
          message.roomId,
          message.content.preview,
          message.sentAt,
        );
        _notifier.notify('messages:${message.roomId}');
        _notifier.notify('rooms');

        // 수신 완료 → 서버에서 즉시 삭제 (ephemeral) / delivered 표시 (retain)
        await _transport.acknowledge(envelopeId: envelope.id, userId: userId);
      } catch (_) {
        // 저장 실패 시 ack하지 않음 → 서버에 남아 다음 접속 때 재전달됨
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
