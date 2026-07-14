import 'dart:async';

import '../core/entities.dart';
import '../core/errors.dart';
import '../core/repositories.dart';
import '../core/retention.dart';
import 'chat_transport.dart';
import 'emoticon_store.dart';
import 'local_store.dart';
import 'phone_number_hasher.dart';

/// 로컬 저장소 변경을 관찰자에게 알리는 초경량 이벤트 버스.
/// key 예: "messages:{roomId}", "rooms", "friends", "emoticons"
class ChangeNotifierBus {
  final _controllers = <String, StreamController<void>>{};

  Stream<void> stream(String key) =>
      (_controllers[key] ??= StreamController<void>.broadcast()).stream;

  void notify(String key) {
    final controller = _controllers[key];
    if (controller != null && !controller.isClosed) controller.add(null);
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}

class DefaultUserRepository implements UserRepository {
  final LocalStore _store;
  final ChatTransport _transport;

  DefaultUserRepository(this._store, this._transport);

  @override
  Future<User?> currentUser() => _store.currentUser();

  @override
  Future<User> register({required String nickname, required String phoneNumber}) async {
    final user = User(
      id: _newId(),
      nickname: nickname,
      phoneNumberHash: PhoneNumberHasher.hash(phoneNumber),
      createdAt: DateTime.now(),
    );
    await _transport.register(user);
    await _store.saveUser(user);
    return user;
  }

  @override
  Future<void> updateProfileImages({String? profilePath, String? coverPath}) =>
      _store.updateProfileImages(profilePath: profilePath, coverPath: coverPath);

  @override
  Future<void> updateStatusMessage(String? status) =>
      _store.updateStatusMessage(status);
}

class DefaultFriendRepository implements FriendRepository {
  final LocalStore _store;
  final ChatTransport _transport;
  final ChangeNotifierBus _notifier;

  DefaultFriendRepository(this._store, this._transport, this._notifier);

  @override
  Future<List<FriendCandidate>> findCandidates(List<DeviceContact> contacts) async {
    // 해시 → 연락처 이름 매핑
    final nameByHash = <String, String>{
      for (final contact in contacts)
        for (final number in contact.phoneNumbers)
          PhoneNumberHasher.hash(number): contact.name,
    };
    if (nameByHash.isEmpty && contacts.isEmpty) {
      // 봇 노출을 위해 빈 조회도 허용
    }

    final matched = await _transport.lookup(nameByHash.keys.toList());
    final alreadyFriends = {for (final f in await _store.friends()) f.id};
    final myId = (await _store.currentUser())?.id;

    final candidates = [
      for (final user in matched)
        if (user.id != myId && !alreadyFriends.contains(user.id))
          FriendCandidate(
            id: user.id,
            nickname: user.nickname,
            localName: nameByHash[user.phoneNumberHash],
          ),
    ]..sort((a, b) => (a.localName ?? a.nickname).compareTo(b.localName ?? b.nickname));
    return candidates;
  }

  @override
  Future<List<Friend>> addFriends(List<FriendCandidate> candidates) async {
    // 친구 목록은 서버에 올리지 않는다 (개인정보 최소화 — 기기에만 저장)
    final now = DateTime.now();
    final newFriends = [
      for (final c in candidates)
        Friend(id: c.id, nickname: c.nickname, localName: c.localName, addedAt: now),
    ];
    await _store.upsertFriends(newFriends);
    _notifier.notify('friends');
    return newFriends;
  }

  @override
  Future<List<Friend>> friends() => _store.friends();

  @override
  Future<List<Friend>> managedFriends() => _store.managedFriends();

  @override
  Future<void> setStatus(String id, FriendStatus status) async {
    await _store.setFriendStatus(id, status);
    _notifier.notify('friends');
  }
}

class DefaultChatRoomRepository implements ChatRoomRepository {
  final LocalStore _store;
  final ChangeNotifierBus _notifier;

  DefaultChatRoomRepository(this._store, this._notifier);

  @override
  Future<ChatRoom> createRoom({
    required RoomKind kind,
    String? name,
    required List<String> memberIds,
  }) async {
    if (kind == RoomKind.direct) {
      final existing = await _store.existingDirectRoom(memberIds);
      if (existing != null) return existing;
    }
    final room = ChatRoom(
      id: _newId(),
      kind: kind,
      name: name,
      memberIds: memberIds,
      createdAt: DateTime.now(),
    );
    await _store.upsertRoom(room);
    _notifier.notify('rooms');
    return room;
  }

  @override
  Future<List<ChatRoom>> rooms() => _store.rooms();

  @override
  Future<ChatRoom?> room(String id) => _store.room(id);

  @override
  Stream<List<ChatRoom>> observeRooms() async* {
    yield await _store.rooms();
    await for (final _ in _notifier.stream('rooms')) {
      yield await _store.rooms();
    }
  }
}

class DefaultMessageRepository implements MessageRepository {
  final LocalStore _store;
  final ChatTransport _transport;
  final ChangeNotifierBus _notifier;

  DefaultMessageRepository(this._store, this._transport, this._notifier);

  @override
  Future<Message> send(MessageContent content, {required String roomId}) async {
    final me = await _store.currentUser();
    if (me == null) throw const NotRegisteredException();
    final room = await _store.room(roomId);
    if (room == null) throw RoomNotFoundException(roomId);

    // 1) 로컬에 즉시 저장 → 내 화면에 바로 표시
    var message = Message(
      id: _newId(),
      roomId: roomId,
      senderId: me.id,
      content: content,
      sentAt: DateTime.now(),
    );
    await _store.insertMessage(message);
    await _store.updateRoomPreview(roomId, content.preview, message.sentAt);
    _notifier.notify('messages:$roomId');
    _notifier.notify('rooms');

    // 2) 서버(우체통)에 업로드 — 나를 제외한 멤버에게 fan-out
    final recipients = room.memberIds.where((id) => id != me.id).toList();
    try {
      await _transport.send(
        TransportEnvelope(message: message, room: room, sender: me),
        recipientIds: recipients,
      );
      message = message.copyWith(deliveryState: DeliveryState.sent);
    } catch (_) {
      message = message.copyWith(deliveryState: DeliveryState.failed);
    }
    await _store.updateMessageState(message.id, message.deliveryState);
    _notifier.notify('messages:$roomId');

    if (message.deliveryState == DeliveryState.failed) {
      throw const TransportException('error.sendFailed');
    }
    return message;
  }

  @override
  Future<void> sendReadReceipt(
      {required String roomId, required List<String> messageIds}) async {
    if (messageIds.isEmpty) return;
    final me = await _store.currentUser();
    if (me == null) return;
    final room = await _store.room(roomId);
    if (room == null) return;

    // 제어 메시지 — 로컬 저장 없이 다른 멤버에게만 업로드
    final receipt = Message(
      id: _newId(),
      roomId: roomId,
      senderId: me.id,
      content: ReadReceiptContent(messageIds),
      sentAt: DateTime.now(),
      deliveryState: DeliveryState.sent,
    );
    final recipients = room.memberIds.where((id) => id != me.id).toList();
    if (recipients.isEmpty) return;
    try {
      await _transport.send(
        TransportEnvelope(message: receipt, room: room, sender: me),
        recipientIds: recipients,
      );
    } catch (_) {
      // 읽음 신호는 실패해도 조용히 무시 (핵심 기능 아님)
    }
  }

  @override
  Future<List<Message>> messages(String roomId) => _store.messages(roomId);

  @override
  Stream<List<Message>> observeMessages(String roomId) async* {
    yield await _store.messages(roomId);
    await for (final _ in _notifier.stream('messages:$roomId')) {
      yield await _store.messages(roomId);
    }
  }

  @override
  Future<int> purgeExpired(RetentionPolicy policy) async {
    final cutoff = policy.expirationCutoff();
    if (cutoff == null) return 0;
    final count = await _store.purgeMessages(olderThan: cutoff);
    if (count > 0) _notifier.notify('rooms');
    return count;
  }
}

class DefaultEmoticonRepository implements EmoticonRepository {
  final LocalStore _store;
  final EmoticonStore _gallery;
  final ChangeNotifierBus _notifier;

  DefaultEmoticonRepository(this._store, this._gallery, this._notifier);

  @override
  Future<Emoticon> upload(Emoticon emoticon) async {
    await _gallery.upload(emoticon);
    return emoticon;
  }

  @override
  Future<List<Emoticon>> browse() => _gallery.fetchAll();

  @override
  Future<List<Emoticon>> myCollection() => _store.myEmoticons();

  @override
  Future<bool> isInCollection(String id) => _store.hasEmoticon(id);

  @override
  Future<void> addToCollection(Emoticon emoticon) async {
    await _store.addEmoticon(emoticon);
    _notifier.notify('emoticons');
  }
}

int _idCounter = 0;

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_idCounter++).toRadixString(36)}';
