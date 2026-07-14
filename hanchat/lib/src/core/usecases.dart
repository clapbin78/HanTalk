// UseCase — View/ViewModel의 유일한 진입점 (Repository 직접 접근 금지).
// 검증 실패 메시지는 현지화 키(l10n key)로 던지고 UI에서 번역해 표시한다.
import 'entities.dart';
import 'errors.dart';
import 'repositories.dart';
import 'retention.dart';

class RegisterUserUseCase {
  final UserRepository _users;
  const RegisterUserUseCase(this._users);

  Future<User> call({required String nickname, required String phoneNumber}) {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) throw const ValidationException('error.nicknameRequired');
    return _users.register(nickname: trimmed, phoneNumber: phoneNumber);
  }
}

class GetCurrentUserUseCase {
  final UserRepository _users;
  const GetCurrentUserUseCase(this._users);
  Future<User?> call() => _users.currentUser();
}

/// 프로필/배경 사진 갱신 (로컬 전용). 이미지 파일은 UI가 앱 문서 폴더에
/// 리사이즈해서 저장하고, 여기엔 그 경로만 넘긴다.
class UpdateProfileImagesUseCase {
  final UserRepository _users;
  const UpdateProfileImagesUseCase(this._users);

  Future<void> call({String? profilePath, String? coverPath}) =>
      _users.updateProfileImages(profilePath: profilePath, coverPath: coverPath);
}

class SyncContactsUseCase {
  final FriendRepository _friends;
  const SyncContactsUseCase(this._friends);

  /// 1단계: 연락처에서 가입자 후보 찾기.
  Future<List<FriendCandidate>> findCandidates(List<DeviceContact> contacts) =>
      _friends.findCandidates(contacts);

  /// 2단계: 등록 (mode == all이면 후보 전체, manual이면 선택분만).
  Future<List<Friend>> register(List<FriendCandidate> selection) =>
      _friends.addFriends(selection);
}

class GetFriendsUseCase {
  final FriendRepository _friends;
  const GetFriendsUseCase(this._friends);
  Future<List<Friend>> call() => _friends.friends();
}

/// 친구 차단/삭제/복원 관리.
class ManageFriendsUseCase {
  final FriendRepository _friends;
  const ManageFriendsUseCase(this._friends);

  /// 차단: 목록에서 숨기고, 이후 이 사람이 보내는 메시지는 수신 시점에 버려진다.
  Future<void> block(String id) => _friends.setStatus(id, FriendStatus.blocked);

  /// 삭제: 목록에서만 숨김 (메시지 수신은 유지 — 문자 감성).
  Future<void> hide(String id) => _friends.setStatus(id, FriendStatus.hidden);

  /// 복원: 다시 활성 친구로.
  Future<void> restore(String id) => _friends.setStatus(id, FriendStatus.active);

  /// 차단/삭제된 친구 목록 (관리 화면).
  Future<List<Friend>> managed() => _friends.managedFriends();
}

class CreateChatRoomUseCase {
  final ChatRoomRepository _rooms;
  const CreateChatRoomUseCase(this._rooms);

  Future<ChatRoom> direct({required String friendId, required String myId}) =>
      _rooms.createRoom(kind: RoomKind.direct, memberIds: [myId, friendId]);

  Future<ChatRoom> group({required String name, required List<String> memberIds}) {
    if (memberIds.length < 3) throw const ValidationException('error.groupMinMembers');
    return _rooms.createRoom(kind: RoomKind.group, name: name, memberIds: memberIds);
  }
}

class ObserveChatRoomsUseCase {
  final ChatRoomRepository _rooms;
  const ObserveChatRoomsUseCase(this._rooms);
  Stream<List<ChatRoom>> call() => _rooms.observeRooms();
}

class SendMessageUseCase {
  final MessageRepository _messages;
  const SendMessageUseCase(this._messages);

  Future<Message> call(MessageContent content, {required String roomId}) {
    if (content case TextContent(text: final t) when t.trim().isEmpty) {
      throw const ValidationException('error.emptyMessage');
    }
    return _messages.send(content, roomId: roomId);
  }
}

class ObserveMessagesUseCase {
  final MessageRepository _messages;
  const ObserveMessagesUseCase(this._messages);
  Stream<List<Message>> call(String roomId) => _messages.observeMessages(roomId);
}

/// 방을 열었을 때 상대 메시지들에 읽음 신호 전송.
/// enabled(내 읽음표시 설정)가 true일 때만 보낸다 → 상호 opt-in.
class MarkRoomReadUseCase {
  final MessageRepository _messages;
  const MarkRoomReadUseCase(this._messages);

  Future<void> call({
    required String roomId,
    required List<Message> messages,
    required String myId,
    required bool enabled,
  }) async {
    if (!enabled) return;
    final incomingIds = [
      for (final m in messages)
        if (m.senderId != myId && m.content.isVisible) m.id,
    ];
    await _messages.sendReadReceipt(roomId: roomId, messageIds: incomingIds);
  }
}

class PurgeExpiredMessagesUseCase {
  final MessageRepository _messages;
  final RetentionPolicy _policy;
  const PurgeExpiredMessagesUseCase(this._messages, this._policy);

  /// 앱 시작/포그라운드 진입 시 호출. 삭제 개수 반환.
  Future<int> call() => _messages.purgeExpired(_policy);
}

// ── 이모티콘 ──────────────────────────────────────────────

class UploadEmoticonUseCase {
  final EmoticonRepository _emoticons;
  final UserRepository _users;

  /// HanChatConfig.paidEmoticonsEnabled 주입 (🚩 Phase 3에서 켬)
  final bool allowPaid;

  const UploadEmoticonUseCase(this._emoticons, this._users, {required this.allowPaid});

  Future<Emoticon> call({
    required String name,
    required DrawingPayload payload,
    int price = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationException('error.emoticonNameRequired');
    if (payload.strokes.isEmpty) throw const ValidationException('error.drawingRequired');
    if (price < 0) throw const ValidationException('error.priceNegative');
    if (price > 0 && !allowPaid) throw const FeatureDisabledException();

    final me = await _users.currentUser();
    if (me == null) throw const NotRegisteredException();

    final emoticon = Emoticon(
      id: _newId(),
      name: trimmed,
      creatorId: me.id,
      creatorNickname: me.nickname,
      payload: payload,
      price: price,
      createdAt: DateTime.now(),
    );
    final uploaded = await _emoticons.upload(emoticon);
    await _emoticons.addToCollection(uploaded); // 내가 만든 건 자동 보관함
    return uploaded;
  }
}

class BrowseEmoticonsUseCase {
  final EmoticonRepository _emoticons;
  const BrowseEmoticonsUseCase(this._emoticons);
  Future<List<Emoticon>> call() => _emoticons.browse();
}

class GetMyEmoticonsUseCase {
  final EmoticonRepository _emoticons;
  const GetMyEmoticonsUseCase(this._emoticons);
  Future<List<Emoticon>> call() => _emoticons.myCollection();
}

/// 이모티콘 받기(무료) / 구매(유료 — 플래그 뒤 숨겨진 경로).
enum AcquireOutcome { alreadyOwned, addedFree, purchased }

class AcquireEmoticonUseCase {
  final EmoticonRepository _emoticons;
  final UserRepository _users;
  final PaymentGateway _payment;

  const AcquireEmoticonUseCase(this._emoticons, this._users, this._payment);

  Future<AcquireOutcome> call(Emoticon emoticon) async {
    // 1) 중복 획득/중복 결제 방지
    if (await _emoticons.isInCollection(emoticon.id)) {
      return AcquireOutcome.alreadyOwned;
    }
    final me = await _users.currentUser();
    if (me == null) throw const NotRegisteredException();

    // 2) 유료면 결제 먼저 (실패 시 보관함에 추가되지 않음)
    var outcome = AcquireOutcome.addedFree;
    if (!emoticon.isFree) {
      await _payment.charge(
        amount: emoticon.price,
        emoticonId: emoticon.id,
        buyerId: me.id,
      );
      outcome = AcquireOutcome.purchased;
    }

    // 3) 보관함 추가
    await _emoticons.addToCollection(emoticon);
    return outcome;
  }
}

// ── 번역 · AI ─────────────────────────────────────────────

class TranslateTextUseCase {
  final TranslationService _service;
  const TranslateTextUseCase(this._service);

  Future<String> call(String text, {required String toLanguage}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;
    return _service.translate(trimmed, toLanguage: toLanguage);
  }
}

class SuggestRepliesUseCase {
  final AIAssistantService _ai;

  /// HanChatConfig.aiAssistantEnabled 주입 (🚩 Phase 4에서 켬)
  final bool enabled;

  const SuggestRepliesUseCase(this._ai, {required this.enabled});

  Future<List<String>> call({
    required List<Message> context,
    required String languageCode,
  }) async {
    if (!enabled) throw const FeatureDisabledException();
    if (context.isEmpty) return [];
    // 최근 10개만 — 토큰(비용) 절약
    final recent = context.length <= 10 ? context : context.sublist(context.length - 10);
    return _ai.suggestReplies(context: recent, languageCode: languageCode);
  }
}

// ── 내부 유틸 ─────────────────────────────────────────────

int _idCounter = 0;

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_idCounter++).toRadixString(36)}';
