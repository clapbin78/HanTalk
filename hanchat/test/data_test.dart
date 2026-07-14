// data 레이어 통합 테스트 — 실제 sqlite(FFI) + 인메모리 트랜스포트로
// "보내기 → 우체통 → 수신 → ack → 24시간 삭제" 전체 흐름 검증.
import 'package:flutter_test/flutter_test.dart';
import 'package:hanchat/hanchat.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<HanChatClient> makeClient(
  ChatTransport transport, {
  RetentionPolicy retention = RetentionPolicy.oneDay,
}) {
  return HanChatClient.create(HanChatConfig(
    transport: transport,
    localRetention: retention,
    databasePath: inMemoryDatabasePath,
    databaseFactory: databaseFactoryFfi,
  ));
}

void main() {
  sqfliteFfiInit();

  test('가입 → 현재 사용자 조회', () async {
    final client = await makeClient(InMemoryChatTransport(botEnabled: false));

    expect(await client.getCurrentUser(), isNull);
    final me =
        await client.registerUser(nickname: '천재', phoneNumber: '010-1234-5678');
    expect(me.nickname, '천재');
    expect((await client.getCurrentUser())?.id, me.id);
  });

  test('메시지 전송: 로컬 저장 + 방 미리보기 + 우체통 도착', () async {
    final transport = InMemoryChatTransport(botEnabled: false);
    final client = await makeClient(transport);
    final me = await client.registerUser(nickname: '나', phoneNumber: '01011112222');

    final room = await client.createRoom.direct(friendId: 'friend-1', myId: me.id);
    await client.sendMessage(const TextContent('안녕!'), roomId: room.id);

    final messages = await client.messageRepository.messages(room.id);
    expect(messages.single.deliveryState, DeliveryState.sent);

    final rooms = await client.roomRepository.rooms();
    expect(rooms.single.lastMessagePreview, '안녕!');

    // 상대 우편함에 봉투 도착
    final envelope = await transport.incoming('friend-1').first;
    expect(envelope.message.content.preview, '안녕!');
  });

  test('수신 파이프라인: 봉투 → 방 자동생성 + 저장 + 발신자 친구 등록', () async {
    final transport = InMemoryChatTransport(botEnabled: false);
    final client = await makeClient(transport);
    final me = await client.registerUser(nickname: '나', phoneNumber: '01011112222');
    await client.start(); // 수신 구독 시작

    // 상대가 보낸 것처럼 봉투 투입
    final sender = User(
      id: 'other-1',
      nickname: '상대방',
      phoneNumberHash: 'h',
      createdAt: DateTime.now(),
    );
    final room = ChatRoom(
      id: 'new-room',
      kind: RoomKind.direct,
      memberIds: ['other-1', me.id],
      createdAt: DateTime.now(),
    );
    final incoming = Message(
      id: 'in-1',
      roomId: room.id,
      senderId: sender.id,
      content: const TextContent('처음 뵙겠습니다'),
      sentAt: DateTime.now(),
    );
    await transport.send(
      TransportEnvelope(message: incoming, room: room, sender: sender),
      recipientIds: [me.id],
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 방이 자동 생성되고 메시지 저장됨
    final saved = await client.messageRepository.messages('new-room');
    expect(saved.single.deliveryState, DeliveryState.delivered);
    // 모르는 발신자는 닉네임으로 친구 목록에 표시용 등록
    final friends = await client.getFriends();
    expect(friends.any((f) => f.id == 'other-1'), isTrue);

    await client.stop();
  });

  test('1:1 방 중복 생성 방지', () async {
    final client = await makeClient(InMemoryChatTransport(botEnabled: false));
    final me = await client.registerUser(nickname: '나', phoneNumber: '01011112222');

    final a = await client.createRoom.direct(friendId: 'f1', myId: me.id);
    final b = await client.createRoom.direct(friendId: 'f1', myId: me.id);
    expect(a.id, b.id);
  });

  test('24시간 지난 메시지 자동 삭제', () async {
    final transport = InMemoryChatTransport(botEnabled: false);
    final client = await makeClient(transport);
    final me = await client.registerUser(nickname: '나', phoneNumber: '01011112222');
    final room = await client.createRoom.direct(friendId: 'f1', myId: me.id);

    // 25시간 전 메시지를 수신 경로로 주입
    final old = Message(
      id: 'old-1',
      roomId: room.id,
      senderId: me.id,
      content: const TextContent('어제 메시지'),
      sentAt: DateTime.now().subtract(const Duration(hours: 25)),
      deliveryState: DeliveryState.sent,
    );
    // LocalStore는 내부용이므로 SyncEngine 경로로 주입
    await transport.send(
      TransportEnvelope(message: old, room: room, sender: me),
      recipientIds: [me.id],
    );
    await client.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect((await client.messageRepository.messages(room.id)).length, 1);
    final purged = await client.purgeExpired();
    expect(purged, 1);
    expect(await client.messageRepository.messages(room.id), isEmpty);

    await client.stop();
  });

  test('연락처 매칭 → 친구 등록 (기기에만 저장)', () async {
    final transport = InMemoryChatTransport(
      seedFakeUsers: [(nickname: '김철수', phoneNumber: '010-1111-2222')],
      botEnabled: false,
    );
    final client = await makeClient(transport);
    await client.registerUser(nickname: '나', phoneNumber: '01099998888');

    final candidates = await client.syncContacts.findCandidates([
      const DeviceContact(name: '철수형', phoneNumbers: ['010-1111-2222']),
      const DeviceContact(name: '미가입자', phoneNumbers: ['010-7777-6666']),
    ]);
    expect(candidates.single.localName, '철수형'); // 연락처 이름 우선

    await client.syncContacts.register(candidates);
    final friends = await client.getFriends();
    expect(friends.single.displayName, '철수형');
  });

  test('친구 차단/삭제/복원 + 차단 상대 메시지 드롭', () async {
    final transport = InMemoryChatTransport(
      seedFakeUsers: [(nickname: '김철수', phoneNumber: '010-1111-2222')],
      botEnabled: false,
    );
    final client = await makeClient(transport);
    final me = await client.registerUser(nickname: '나', phoneNumber: '01099998888');

    // 친구 등록
    final candidates = await client.syncContacts.findCandidates(
        [const DeviceContact(name: '철수', phoneNumbers: ['010-1111-2222'])]);
    await client.syncContacts.register(candidates);
    final friend = (await client.getFriends()).single;

    // 삭제(hidden) → 목록에서 사라지고 관리 목록에 등장
    await client.manageFriends.hide(friend.id);
    expect(await client.getFriends(), isEmpty);
    expect((await client.manageFriends.managed()).single.status, FriendStatus.hidden);

    // 복원 → 다시 목록에
    await client.manageFriends.restore(friend.id);
    expect((await client.getFriends()).single.id, friend.id);

    // 차단 → 그 상대가 보낸 메시지는 저장되지 않고 서버에서만 삭제됨
    await client.manageFriends.block(friend.id);
    await client.start();

    final room = ChatRoom(
      id: 'blocked-room',
      kind: RoomKind.direct,
      memberIds: [friend.id, me.id],
      createdAt: DateTime.now(),
    );
    await transport.send(
      TransportEnvelope(
        message: Message(
          id: 'blocked-1',
          roomId: room.id,
          senderId: friend.id,
          content: const TextContent('차단됐는데 보내봄'),
          sentAt: DateTime.now(),
        ),
        room: room,
        sender: User(
            id: friend.id,
            nickname: '김철수',
            phoneNumberHash: 'h',
            createdAt: DateTime.now()),
      ),
      recipientIds: [me.id],
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await client.messageRepository.messages(room.id), isEmpty,
        reason: '차단한 상대의 메시지는 저장되지 않아야 함');
    await client.stop();
  });

  test('이모티콘 보관함: sqlite 저장 + 중복 방지', () async {
    final client = await makeClient(InMemoryChatTransport(botEnabled: false));
    await client.registerUser(nickname: '나', phoneNumber: '01011112222');

    final gallery = await client.browseEmoticons();
    expect(gallery.length, 2); // 샘플 하트/별

    await client.acquireEmoticon(gallery.first);
    await client.acquireEmoticon(gallery.first); // 중복
    expect((await client.getMyEmoticons()).length, 1);
  });
}
