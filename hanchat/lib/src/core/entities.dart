// 도메인 엔티티 — 순수 Dart (Flutter/Firebase/DB 의존 금지)
// Swift 버전(ios-native 브랜치)과 JSON 포맷 100% 호환 유지.

/// 서비스에 가입한 사용자.
class User {
  final String id;
  final String nickname;

  /// 원본 전화번호는 절대 서버로 보내지 않는다. 매칭에는 해시만 사용.
  final String phoneNumberHash;
  final DateTime createdAt;

  /// 프로필 사진 · 배경 사진의 로컬 파일 경로 (기기에만 저장, 서버 미전송).
  final String? profileImagePath;
  final String? coverImagePath;

  const User({
    required this.id,
    required this.nickname,
    required this.phoneNumberHash,
    required this.createdAt,
    this.profileImagePath,
    this.coverImagePath,
  });

  User copyWith({String? profileImagePath, String? coverImagePath}) => User(
        id: id,
        nickname: nickname,
        phoneNumberHash: phoneNumberHash,
        createdAt: createdAt,
        profileImagePath: profileImagePath ?? this.profileImagePath,
        coverImagePath: coverImagePath ?? this.coverImagePath,
      );

  // 서버로 나가는 JSON에는 이미지 경로를 포함하지 않는다 (로컬 전용).
  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'phoneNumberHash': phoneNumberHash,
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        phoneNumberHash: json['phoneNumberHash'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 친구 상태.
/// - active: 정상 (친구 목록 표시)
/// - hidden: 삭제됨 (목록에서 숨김, 메시지 수신은 됨 — 관리 화면에서 복원 가능)
/// - blocked: 차단됨 (목록 숨김 + 메시지 수신 차단 — 복원 가능)
enum FriendStatus { active, hidden, blocked }

/// 내 친구 목록에 등록된 상대.
class Friend {
  final String id; // 상대 User.id
  final String nickname; // 서버 닉네임
  final String? localName; // 내 연락처에 저장된 이름 (우선 표시)
  final DateTime addedAt;
  final FriendStatus status;

  const Friend({
    required this.id,
    required this.nickname,
    this.localName,
    required this.addedAt,
    this.status = FriendStatus.active,
  });

  String get displayName => localName ?? nickname;
}

/// 기기 연락처에서 읽어온 항목 (플랫폼 비의존 도메인 표현).
class DeviceContact {
  final String name;
  final List<String> phoneNumbers;

  const DeviceContact({required this.name, required this.phoneNumbers});
}

/// 연락처 중 서비스 가입자로 확인된 친구 후보.
class FriendCandidate {
  final String id; // 상대 User.id
  final String nickname;
  final String? localName;

  const FriendCandidate({required this.id, required this.nickname, this.localName});
}

/// 연락처 동기화 방식: 전체 자동 등록 / 직접 선택.
enum ContactSyncMode { all, manual }

/// 1:1 또는 그룹 채팅방.
enum RoomKind { direct, group }

class ChatRoom {
  final String id;
  final RoomKind kind;
  final String? name; // 그룹방 이름. 1:1은 null.
  final List<String> memberIds;
  final DateTime createdAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  const ChatRoom({
    required this.id,
    required this.kind,
    this.name,
    required this.memberIds,
    required this.createdAt,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'memberIDs': memberIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        id: json['id'] as String,
        kind: RoomKind.values.byName(json['kind'] as String),
        name: json['name'] as String?,
        memberIds: (json['memberIDs'] as List).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// 메시지 전달 상태.
enum DeliveryState { sending, sent, delivered, failed }

/// 메시지 내용 — 텍스트 / 그림 / 이모티콘 + 제어신호(읽음).
///
/// sealed class라 나중에 제어 케이스(수정/삭제 통보 등)를 추가하기 쉽다.
/// 제어 케이스(ReadReceiptContent)는 말풍선으로 표시하지 않고 SyncEngine이 처리한다.
sealed class MessageContent {
  const MessageContent();

  /// 화면에 말풍선으로 표시되는 콘텐츠인지 (제어신호는 false).
  bool get isVisible => this is! ReadReceiptContent;

  String get preview => switch (this) {
        TextContent(text: final t) => t,
        DrawingContent() => '🎨',
        EmoticonContent() => '😊',
        ReadReceiptContent() => '', // 표시 안 함
      };

  Map<String, dynamic> toJson() => switch (this) {
        TextContent(text: final t) => {'type': 'text', 'text': t},
        DrawingContent(payload: final p) => {'type': 'drawing', 'payload': p.toJson()},
        EmoticonContent(emoticonId: final id, payload: final p) => {
            'type': 'emoticon',
            'emoticonID': id,
            'payload': p.toJson(),
          },
        ReadReceiptContent(messageIds: final ids) => {
            'type': 'read',
            'messageIDs': ids,
          },
      };

  factory MessageContent.fromJson(Map<String, dynamic> json) =>
      switch (json['type'] as String) {
        'text' => TextContent(json['text'] as String),
        'drawing' =>
          DrawingContent(DrawingPayload.fromJson(json['payload'] as Map<String, dynamic>)),
        'emoticon' => EmoticonContent(
            emoticonId: json['emoticonID'] as String,
            payload: DrawingPayload.fromJson(json['payload'] as Map<String, dynamic>),
          ),
        'read' => ReadReceiptContent(
            (json['messageIDs'] as List).cast<String>()),
        _ => throw FormatException('unknown content type: ${json['type']}'),
      };
}

class TextContent extends MessageContent {
  final String text;
  const TextContent(this.text);
}

class DrawingContent extends MessageContent {
  final DrawingPayload payload;
  const DrawingContent(this.payload);
}

class EmoticonContent extends MessageContent {
  /// 원본 이모티콘 id — 나중에 "사용당 크리에이터 수익" 정산 근거.
  final String emoticonId;
  final DrawingPayload payload;
  const EmoticonContent({required this.emoticonId, required this.payload});
}

/// 읽음 신호 (제어 메시지) — 내가 읽은 메시지 id들을 발신자에게 알린다.
/// 읽음표시를 켠(opt-in) 사용자만 보내고, 받는 쪽도 켠 경우에만 반영한다.
class ReadReceiptContent extends MessageContent {
  final List<String> messageIds;
  const ReadReceiptContent(this.messageIds);
}

/// 채팅 메시지.
class Message {
  final String id;
  final String roomId;
  final String senderId;
  final MessageContent content;
  final DateTime sentAt;
  final DeliveryState deliveryState;

  /// 이 메시지를 읽은 상대 수 (읽음표시 켠 경우에만 채워짐).
  /// 1:1은 0 또는 1, 단톡은 읽은 사람 수.
  final int readCount;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.deliveryState = DeliveryState.sending,
    this.readCount = 0,
  });

  Message copyWith({DeliveryState? deliveryState, int? readCount}) => Message(
        id: id,
        roomId: roomId,
        senderId: senderId,
        content: content,
        sentAt: sentAt,
        deliveryState: deliveryState ?? this.deliveryState,
        readCount: readCount ?? this.readCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomID': roomId,
        'senderID': senderId,
        'content': content.toJson(),
        'sentAt': sentAt.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        roomId: json['roomID'] as String,
        senderId: json['senderID'] as String,
        content: MessageContent.fromJson(json['content'] as Map<String, dynamic>),
        sentAt: DateTime.parse(json['sentAt'] as String),
        deliveryState: DeliveryState.sent,
      );
}

/// 그림 페이로드 — 이미지가 아니라 **획(stroke) 벡터**.
/// 수 KB 수준이라 전송·저장 비용이 거의 없고,
/// 타임스탬프(t) 순서로 다시 그리면 "그리는 과정 재생"이 공짜로 된다.
class DrawingPayload {
  final double canvasWidth;
  final double canvasHeight;
  final List<Stroke> strokes;

  const DrawingPayload({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.strokes,
  });

  /// 전체 그리는 데 걸린 시간(초). 재생 길이 계산용.
  double get totalDuration =>
      strokes.isEmpty || strokes.last.points.isEmpty ? 0 : strokes.last.points.last.t;

  Map<String, dynamic> toJson() => {
        'canvasSize': {'width': canvasWidth, 'height': canvasHeight},
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory DrawingPayload.fromJson(Map<String, dynamic> json) {
    final size = json['canvasSize'] as Map<String, dynamic>;
    return DrawingPayload(
      canvasWidth: (size['width'] as num).toDouble(),
      canvasHeight: (size['height'] as num).toDouble(),
      strokes: (json['strokes'] as List)
          .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 펜 한 획. 설정 가능한 것은 색상과 두께뿐 (미니 그림판 요구사항).
class Stroke {
  final String colorHex; // "#RRGGBB"
  final double width;
  final List<StrokePoint> points;

  const Stroke({required this.colorHex, required this.width, required this.points});

  Map<String, dynamic> toJson() => {
        'colorHex': colorHex,
        'width': width,
        'points': points.map((p) => {'x': p.x, 'y': p.y, 't': p.t}).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        colorHex: json['colorHex'] as String,
        width: (json['width'] as num).toDouble(),
        points: (json['points'] as List)
            .map((p) => StrokePoint(
                  x: ((p as Map)['x'] as num).toDouble(),
                  y: (p['y'] as num).toDouble(),
                  t: (p['t'] as num).toDouble(),
                ))
            .toList(),
      );
}

class StrokePoint {
  final double x;
  final double y;

  /// 그리기 시작 시점 기준 경과 시간(초). 재생용.
  final double t;

  const StrokePoint({required this.x, required this.y, required this.t});
}

/// 이모티콘 갤러리에 공개된 이모티콘.
class Emoticon {
  final String id;
  final String name;
  final String creatorId;
  final String creatorNickname;
  final DrawingPayload payload;

  /// 가격(원). 0 = 무료. 유료 판매는 paidEmoticonsEnabled 플래그로 숨김 (Phase 3).
  final int price;
  final DateTime createdAt;

  const Emoticon({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.creatorNickname,
    required this.payload,
    this.price = 0,
    required this.createdAt,
  });

  bool get isFree => price == 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'creatorID': creatorId,
        'creatorNickname': creatorNickname,
        'payload': payload.toJson(),
        'price': price,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Emoticon.fromJson(Map<String, dynamic> json) => Emoticon(
        id: json['id'] as String,
        name: json['name'] as String,
        creatorId: json['creatorID'] as String,
        creatorNickname: json['creatorNickname'] as String,
        payload: DrawingPayload.fromJson(json['payload'] as Map<String, dynamic>),
        price: json['price'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
