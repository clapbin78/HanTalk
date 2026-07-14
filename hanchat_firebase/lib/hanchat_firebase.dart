/// hanchat의 Firebase 백엔드 어댑터.
///
/// Firestore 구조 (서버 = 우체통):
/// ```
/// users/{userID}                     ← 닉네임 + 전화번호 해시 (친구 매칭용)
/// mailboxes/{recipientID}/envelopes/{messageID}
///     ├ payload: TransportEnvelope JSON
///     ├ delivered: retain 모드의 중복 수신 방지 플래그
///     └ expiresAt: TTL 정책 대상 (firebase/README 참고)
/// emoticons/{emoticonID}             ← 공개 갤러리 (영구)
/// ```
library hanchat_firebase;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:hanchat/hanchat.dart';

/// ChatTransport의 Firebase 구현.
///
/// 보관 정책 (ServerRetention):
/// - ephemeral (기본): ack 시 봉투 즉시 삭제 → 채팅 내용이 서버에 남지 않음
/// - retain(days: n): 일반 메신저처럼 n일 보관. ack 시 delivered 표시만, TTL이 삭제.
class FirebaseChatTransport implements ChatTransport {
  final FirebaseFirestore _db;
  final ServerRetention retention;

  FirebaseChatTransport({
    FirebaseFirestore? firestore,
    this.retention = ServerRetention.ephemeral,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  /// 익명 인증 (전화번호 인증은 Phase 2에서 교체 가능)
  static Future<void> signInIfNeeded() async {
    final auth = fb_auth.FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  @override
  Future<void> register(User user) async {
    await signInIfNeeded();
    await _db.collection('users').doc(user.id).set({
      'nickname': user.nickname,
      'phoneNumberHash': user.phoneNumberHash,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<RemoteUser>> lookup(List<String> phoneNumberHashes) async {
    await signInIfNeeded();
    final results = <RemoteUser>[];
    // Firestore whereIn은 한 번에 30개 제한 → 청크 분할
    for (var i = 0; i < phoneNumberHashes.length; i += 30) {
      final chunk = phoneNumberHashes.sublist(
        i,
        i + 30 > phoneNumberHashes.length ? phoneNumberHashes.length : i + 30,
      );
      if (chunk.isEmpty) continue;
      final snapshot = await _db
          .collection('users')
          .where('phoneNumberHash', whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        results.add(RemoteUser(
          id: doc.id,
          nickname: data['nickname'] as String? ?? '',
          phoneNumberHash: data['phoneNumberHash'] as String? ?? '',
        ));
      }
    }
    return results;
  }

  @override
  Future<void> send(
    TransportEnvelope envelope, {
    required List<String> recipientIds,
  }) async {
    await signInIfNeeded();
    final payload = jsonEncode(envelope.toJson());
    final batch = _db.batch();
    for (final recipient in recipientIds) {
      final ref = _db
          .collection('mailboxes')
          .doc(recipient)
          .collection('envelopes')
          .doc(envelope.id);
      batch.set(ref, {
        'payload': payload,
        'senderID': envelope.sender.id,
        'delivered': false,
        'createdAt': FieldValue.serverTimestamp(),
        // Firestore TTL 정책 대상 필드 — 콘솔에서 TTL 설정 필요
        'expiresAt': Timestamp.fromDate(DateTime.now().add(retention.ttl)),
      });
    }
    await batch.commit();
  }

  @override
  Stream<TransportEnvelope> incoming(String userId) {
    return _db
        .collection('mailboxes')
        .doc(userId)
        .collection('envelopes')
        .where('delivered', isEqualTo: false) // retain 모드 중복 수신 방지
        .orderBy('createdAt')
        .snapshots()
        .expand((snapshot) sync* {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final payload = change.doc.data()?['payload'] as String?;
        if (payload == null) continue;
        try {
          yield TransportEnvelope.fromJson(
              jsonDecode(payload) as Map<String, dynamic>);
        } catch (_) {
          // 손상된 봉투는 건너뜀 (TTL이 정리)
        }
      }
    });
  }

  @override
  Future<void> acknowledge({
    required String envelopeId,
    required String userId,
  }) async {
    final ref = _db
        .collection('mailboxes')
        .doc(userId)
        .collection('envelopes')
        .doc(envelopeId);
    if (retention.deletesOnAcknowledge) {
      await ref.delete(); // ephemeral: 서버에서 즉시 삭제
    } else {
      await ref.update({
        'delivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

/// EmoticonStore의 Firebase 구현 — 공개 갤러리 (벡터 JSON, 수 KB).
class FirebaseEmoticonStore implements EmoticonStore {
  final FirebaseFirestore _db;

  FirebaseEmoticonStore({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> upload(Emoticon emoticon) async {
    await FirebaseChatTransport.signInIfNeeded();
    await _db.collection('emoticons').doc(emoticon.id).set({
      'json': jsonEncode(emoticon.toJson()),
      'createdAt': Timestamp.fromDate(emoticon.createdAt),
    });
  }

  @override
  Future<List<Emoticon>> fetchAll() async {
    await FirebaseChatTransport.signInIfNeeded();
    final snapshot = await _db
        .collection('emoticons')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return [
      for (final doc in snapshot.docs)
        if (doc.data()['json'] case final String json)
          Emoticon.fromJson(jsonDecode(json) as Map<String, dynamic>),
    ];
  }
}
