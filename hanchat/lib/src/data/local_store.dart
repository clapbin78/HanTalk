import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/entities.dart';

/// sqflite 로컬 저장소 (Swift 버전의 SwiftData LocalStore 대응).
/// 모든 로컬 읽기/쓰기는 여기를 거친다. data 레이어 내부 전용.
class LocalStore {
  final Database _db;
  LocalStore._(this._db);

  /// [factory]는 테스트에서 sqflite_common_ffi 주입용.
  static Future<LocalStore> open({
    required String path,
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        // 같은 경로 재사용 시 인스턴스 공유 방지 (테스트 격리 + 명시적 수명 관리)
        singleInstance: false,
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            // v2: 친구 상태(active/hidden/blocked) 추가
            await db.execute(
                "ALTER TABLE friends ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
          }
          if (oldVersion < 3) {
            // v3: 읽음표시 — 읽은 사람 id JSON 배열
            await db.execute(
                "ALTER TABLE messages ADD COLUMN read_by TEXT NOT NULL DEFAULT '[]'");
          }
          if (oldVersion < 4) {
            // v4: 프로필/배경 사진 로컬 경로
            await db.execute("ALTER TABLE users ADD COLUMN profile_path TEXT");
            await db.execute("ALTER TABLE users ADD COLUMN cover_path TEXT");
          }
          if (oldVersion < 5) {
            // v5: 상태메시지
            await db.execute("ALTER TABLE users ADD COLUMN status_msg TEXT");
          }
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE users (
              id TEXT PRIMARY KEY, nickname TEXT NOT NULL,
              phone_hash TEXT NOT NULL, created_at TEXT NOT NULL,
              profile_path TEXT, cover_path TEXT, status_msg TEXT
            )''');
          await db.execute('''
            CREATE TABLE friends (
              id TEXT PRIMARY KEY, nickname TEXT NOT NULL,
              local_name TEXT, added_at TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active'
            )''');
          await db.execute('''
            CREATE TABLE rooms (
              id TEXT PRIMARY KEY, kind TEXT NOT NULL, name TEXT,
              member_ids TEXT NOT NULL, created_at TEXT NOT NULL,
              last_preview TEXT, last_at TEXT
            )''');
          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY, room_id TEXT NOT NULL, sender_id TEXT NOT NULL,
              content TEXT NOT NULL, sent_at TEXT NOT NULL, state TEXT NOT NULL,
              read_by TEXT NOT NULL DEFAULT '[]'
            )''');
          await db.execute('CREATE INDEX idx_messages_room ON messages(room_id, sent_at)');
          await db.execute('CREATE INDEX idx_messages_sent ON messages(sent_at)');
          await db.execute('''
            CREATE TABLE emoticons (
              id TEXT PRIMARY KEY, json TEXT NOT NULL, added_at TEXT NOT NULL
            )''');
        },
      ),
    );
    return LocalStore._(db);
  }

  Future<void> close() => _db.close();

  // ── User ──────────────────────────────────────────────

  Future<User?> currentUser() async {
    final rows = await _db.query('users', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return User(
      id: r['id'] as String,
      nickname: r['nickname'] as String,
      phoneNumberHash: r['phone_hash'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      profileImagePath: r['profile_path'] as String?,
      coverImagePath: r['cover_path'] as String?,
      statusMessage: r['status_msg'] as String?,
    );
  }

  Future<void> saveUser(User user) => _db.insert(
        'users',
        {
          'id': user.id,
          'nickname': user.nickname,
          'phone_hash': user.phoneNumberHash,
          'created_at': user.createdAt.toIso8601String(),
          'profile_path': user.profileImagePath,
          'cover_path': user.coverImagePath,
          'status_msg': user.statusMessage,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// 프로필/배경 사진 경로 갱신 (null 전달 시 제거).
  Future<void> updateProfileImages(
      {String? profilePath, String? coverPath}) async {
    await _db.update('users',
        {'profile_path': profilePath, 'cover_path': coverPath});
  }

  /// 상태메시지 갱신.
  Future<void> updateStatusMessage(String? status) async {
    await _db.update('users', {'status_msg': status});
  }

  // ── Friends ───────────────────────────────────────────

  Friend _rowToFriend(Map<String, Object?> r) => Friend(
        id: r['id'] as String,
        nickname: r['nickname'] as String,
        localName: r['local_name'] as String?,
        addedAt: DateTime.parse(r['added_at'] as String),
        status: FriendStatus.values
            .byName((r['status'] as String?) ?? 'active'),
      );

  /// 활성 친구만 (목록 표시용).
  Future<List<Friend>> friends() async {
    final rows = await _db.query('friends',
        where: 'status = ?', whereArgs: ['active'], orderBy: 'added_at');
    return rows.map(_rowToFriend).toList();
  }

  /// 삭제·차단된 친구 (관리 화면용).
  Future<List<Friend>> managedFriends() async {
    final rows = await _db.query('friends',
        where: 'status != ?', whereArgs: ['active'], orderBy: 'added_at');
    return rows.map(_rowToFriend).toList();
  }

  Future<FriendStatus?> friendStatus(String id) async {
    final rows = await _db.query('friends',
        columns: ['status'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return FriendStatus.values.byName(rows.first['status'] as String);
  }

  Future<void> setFriendStatus(String id, FriendStatus status) => _db.update(
        'friends',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// 이미 있는 친구는 닉네임/연락처명만 갱신하고 상태는 유지한다
  /// (재동기화가 차단/삭제 상태를 되돌리지 않도록).
  Future<void> upsertFriends(List<Friend> newFriends) async {
    for (final f in newFriends) {
      final updated = await _db.update(
        'friends',
        {
          'nickname': f.nickname,
          if (f.localName != null) 'local_name': f.localName,
        },
        where: 'id = ?',
        whereArgs: [f.id],
      );
      if (updated == 0) {
        await _db.insert('friends', {
          'id': f.id,
          'nickname': f.nickname,
          'local_name': f.localName,
          'added_at': f.addedAt.toIso8601String(),
          'status': f.status.name,
        });
      }
    }
  }

  // ── Rooms ─────────────────────────────────────────────

  ChatRoom _rowToRoom(Map<String, Object?> r) => ChatRoom(
        id: r['id'] as String,
        kind: RoomKind.values.byName(r['kind'] as String),
        name: r['name'] as String?,
        memberIds: (jsonDecode(r['member_ids'] as String) as List).cast<String>(),
        createdAt: DateTime.parse(r['created_at'] as String),
        lastMessagePreview: r['last_preview'] as String?,
        lastMessageAt:
            r['last_at'] == null ? null : DateTime.parse(r['last_at'] as String),
      );

  Future<List<ChatRoom>> rooms() async {
    final rows = await _db.query('rooms', orderBy: 'last_at DESC');
    return rows.map(_rowToRoom).toList();
  }

  Future<ChatRoom?> room(String id) async {
    final rows = await _db.query('rooms', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _rowToRoom(rows.first);
  }

  /// 같은 멤버 구성의 1:1 방이 있으면 반환.
  Future<ChatRoom?> existingDirectRoom(List<String> memberIds) async {
    final sorted = List.of(memberIds)..sort();
    final rows = await _db.query('rooms', where: 'kind = ?', whereArgs: ['direct']);
    for (final r in rows) {
      final room = _rowToRoom(r);
      final roomSorted = List.of(room.memberIds)..sort();
      if (roomSorted.length == sorted.length &&
          List.generate(sorted.length, (i) => roomSorted[i] == sorted[i]).every((e) => e)) {
        return room;
      }
    }
    return null;
  }

  Future<void> upsertRoom(ChatRoom room) async {
    final existing = await this.room(room.id);
    await _db.insert(
      'rooms',
      {
        'id': room.id,
        'kind': room.kind.name,
        'name': room.name,
        'member_ids': jsonEncode(room.memberIds),
        'created_at': room.createdAt.toIso8601String(),
        // 미리보기는 기존 값 유지 (upsert가 덮어쓰지 않도록)
        'last_preview': existing?.lastMessagePreview,
        'last_at': existing?.lastMessageAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRoomPreview(String roomId, String preview, DateTime at) =>
      _db.update(
        'rooms',
        {'last_preview': preview, 'last_at': at.toIso8601String()},
        where: 'id = ?',
        whereArgs: [roomId],
      );

  // ── Messages ──────────────────────────────────────────

  Future<List<Message>> messages(String roomId) async {
    final rows = await _db.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'sent_at',
    );
    return [
      for (final r in rows)
        Message(
          id: r['id'] as String,
          roomId: r['room_id'] as String,
          senderId: r['sender_id'] as String,
          content: MessageContent.fromJson(
              jsonDecode(r['content'] as String) as Map<String, dynamic>),
          sentAt: DateTime.parse(r['sent_at'] as String),
          deliveryState: DeliveryState.values.byName(r['state'] as String),
          readCount:
              (jsonDecode((r['read_by'] as String?) ?? '[]') as List).length,
        ),
    ];
  }

  /// 내가 보낸 메시지들에 읽은 사람(readerId)을 추가. (읽음표시)
  Future<void> markRead(List<String> messageIds, String readerId) async {
    for (final id in messageIds) {
      final rows = await _db.query('messages',
          columns: ['read_by'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) continue;
      final readers =
          (jsonDecode((rows.first['read_by'] as String?) ?? '[]') as List)
              .cast<String>()
              .toSet();
      if (readers.add(readerId)) {
        await _db.update('messages', {'read_by': jsonEncode(readers.toList())},
            where: 'id = ?', whereArgs: [id]);
      }
    }
  }

  Future<void> insertMessage(Message message) => _db.insert(
        'messages',
        {
          'id': message.id,
          'room_id': message.roomId,
          'sender_id': message.senderId,
          'content': jsonEncode(message.content.toJson()),
          'sent_at': message.sentAt.toIso8601String(),
          'state': message.deliveryState.name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> updateMessageState(String id, DeliveryState state) => _db.update(
        'messages',
        {'state': state.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// 만료 메시지 일괄 삭제. 삭제 개수 반환.
  Future<int> purgeMessages({required DateTime olderThan}) => _db.delete(
        'messages',
        where: 'sent_at < ?',
        whereArgs: [olderThan.toIso8601String()],
      );

  // ── Emoticons (내 보관함 — 기기에만 저장) ─────────────

  Future<List<Emoticon>> myEmoticons() async {
    final rows = await _db.query('emoticons', orderBy: 'added_at DESC');
    return [
      for (final r in rows)
        Emoticon.fromJson(jsonDecode(r['json'] as String) as Map<String, dynamic>),
    ];
  }

  Future<bool> hasEmoticon(String id) async {
    final rows =
        await _db.query('emoticons', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> addEmoticon(Emoticon emoticon) async {
    if (await hasEmoticon(emoticon.id)) return;
    await _db.insert('emoticons', {
      'id': emoticon.id,
      'json': jsonEncode(emoticon.toJson()),
      'added_at': DateTime.now().toIso8601String(),
    });
  }
}
