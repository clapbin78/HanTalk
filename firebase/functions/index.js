/**
 * 한톡 서버 함수 (Firebase Cloud Functions v2)
 *
 * 1. onEnvelopeCreated — 봉투가 우편함에 들어오면 수신자에게 FCM 푸시 발송
 * 2. cleanupExpiredEnvelopes — 24시간 지난 미수신 봉투 일괄 삭제 (안전망)
 *    ※ Firestore 콘솔에서 mailboxes/*/envelopes 컬렉션의 `expiresAt` 필드에
 *      TTL 정책을 걸어두면 이 함수 없이도 자동 삭제된다. 이 함수는 이중 안전망.
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.onEnvelopeCreated = onDocumentCreated(
  "mailboxes/{recipientID}/envelopes/{envelopeID}",
  async (event) => {
    const { recipientID } = event.params;
    const db = getFirestore();

    const userDoc = await db.collection("users").doc(recipientID).get();
    const fcmToken = userDoc.get("fcmToken");
    if (!fcmToken) return;

    // 프라이버시: 푸시에 메시지 내용을 싣지 않는다. 알림만 보내고 내용은 앱이 우편함에서 가져간다.
    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "한톡",
        body: "새 메시지가 도착했어요",
      },
      apns: {
        payload: { aps: { "content-available": 1, sound: "default" } },
      },
    });
  }
);

exports.cleanupExpiredEnvelopes = onSchedule("every 1 hours", async () => {
  const db = getFirestore();
  const now = new Date();
  const expired = await db
    .collectionGroup("envelopes")
    .where("expiresAt", "<", now)
    .limit(500)
    .get();

  const batch = db.batch();
  expired.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log(`만료 봉투 ${expired.size}개 삭제`);
});
