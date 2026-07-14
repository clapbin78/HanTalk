// Repository 추상화 — Domain은 구현(DB/네트워크)을 모른다.
import 'entities.dart';
import 'retention.dart';

abstract interface class UserRepository {
  Future<User?> currentUser();
  Future<User> register({required String nickname, required String phoneNumber});

  /// 프로필/배경 사진 경로 갱신 (기기 로컬 전용, 서버 미전송).
  Future<void> updateProfileImages({String? profilePath, String? coverPath});

  /// 상태메시지 갱신.
  Future<void> updateStatusMessage(String? status);
}

abstract interface class FriendRepository {
  /// 연락처를 서버 가입자와 대조해 친구 후보 반환 (아직 등록 아님).
  Future<List<FriendCandidate>> findCandidates(List<DeviceContact> contacts);
  Future<List<Friend>> addFriends(List<FriendCandidate> candidates);

  /// 활성(active) 친구만.
  Future<List<Friend>> friends();

  /// 삭제(hidden)·차단(blocked)된 친구 — 관리 화면용.
  Future<List<Friend>> managedFriends();

  /// 차단/삭제/복원. (차단은 SyncEngine이 수신 시점에 확인해 메시지를 버린다)
  Future<void> setStatus(String id, FriendStatus status);
}

abstract interface class ChatRoomRepository {
  /// 1:1 방은 같은 상대와 중복 생성하지 않고 기존 방 반환.
  Future<ChatRoom> createRoom({
    required RoomKind kind,
    String? name,
    required List<String> memberIds,
  });
  Future<List<ChatRoom>> rooms();
  Future<ChatRoom?> room(String id);
  Stream<List<ChatRoom>> observeRooms();
}

abstract interface class MessageRepository {
  /// 로컬 저장(즉시 표시) → 서버 업로드 순서로 처리.
  Future<Message> send(MessageContent content, {required String roomId});

  /// 읽음 신호를 방의 다른 멤버(발신자들)에게 전송 (로컬 저장 안 함).
  Future<void> sendReadReceipt(
      {required String roomId, required List<String> messageIds});

  Future<List<Message>> messages(String roomId);
  Stream<List<Message>> observeMessages(String roomId);

  /// 보관 정책에 따라 만료 메시지 삭제. 삭제 개수 반환.
  Future<int> purgeExpired(RetentionPolicy policy);
}

abstract interface class EmoticonRepository {
  Future<Emoticon> upload(Emoticon emoticon);
  Future<List<Emoticon>> browse();
  Future<List<Emoticon>> myCollection();
  Future<bool> isInCollection(String id);
  Future<void> addToCollection(Emoticon emoticon);
}

/// 결제 추상화. Phase 3에서 IAP 코인 차감으로 구현 (지금은 스텁 + UI 숨김).
abstract interface class PaymentGateway {
  /// 성공 시 결제 식별자 반환. 실패 시 throw.
  Future<String> charge({
    required int amount,
    required String emoticonId,
    required String buyerId,
  });
}

/// 번역 추상화 — 핵심 기능 (플래그 없음).
/// 기본: UI가 ML Kit 온디바이스 번역 사용. AI 번역 주입 시 그쪽 경유 (Phase 4).
abstract interface class TranslationService {
  Future<String> translate(String text, {required String toLanguage});
}

/// AI 어시스턴트 추상화 (🚩 aiAssistantEnabled 플래그 뒤 — Phase 4).
abstract interface class AIAssistantService {
  Future<List<String>> suggestReplies({
    required List<Message> context,
    required String languageCode,
  });
}
