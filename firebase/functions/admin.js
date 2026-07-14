/**
 * 관리자 모드 + 시크릿(외부 API 키) 프록시 — Cloud Functions v2
 *
 * 원칙: 비밀번호·API 키는 앱에도 깃에도 절대 두지 않는다.
 *       Firebase Secret Manager에만 저장하고, 검증/호출은 서버에서만 한다.
 *
 * 배포 전 시크릿 등록 (예):
 *   firebase functions:secrets:set ADMIN_PASSWORD
 *   firebase functions:secrets:set PROFANITY_API_KEY
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const crypto = require("crypto");

/**
 * 관리자 잠금 해제 — 앱이 보낸 비밀번호를 서버 시크릿과 비교.
 * 맞으면 짧은 수명의 서명 토큰을 발급 (관리자 API 게이트용).
 */
exports.unlockAdmin = onCall({ secrets: ["ADMIN_PASSWORD"] }, (request) => {
  const input = request.data?.password;
  if (typeof input !== "string") {
    throw new HttpsError("invalid-argument", "password required");
  }
  // 타이밍 공격 방지를 위한 상수시간 비교
  const expected = process.env.ADMIN_PASSWORD || "";
  const a = Buffer.from(input);
  const b = Buffer.from(expected);
  const ok = a.length === b.length && crypto.timingSafeEqual(a, b);
  if (!ok) {
    throw new HttpsError("permission-denied", "wrong password");
  }
  // 데모 수준 토큰. 프로덕션은 App Check + 커스텀 클레임으로 강화 권장.
  const token = crypto
    .createHmac("sha256", expected)
    .update(`${request.auth?.uid || "anon"}:${Date.now()}`)
    .digest("hex");
  return { token };
});

/**
 * 외부 API(예: 욕설 필터) 프록시 — 앱은 키 없이 이 함수만 호출.
 * 키는 서버 시크릿에만 있어 앱을 뜯어도, 깃에서도 노출되지 않는다.
 */
exports.moderateText = onCall({ secrets: ["PROFANITY_API_KEY"] }, async (request) => {
  const text = request.data?.text;
  if (typeof text !== "string") {
    throw new HttpsError("invalid-argument", "text required");
  }
  // 실제 구현 예시 (키는 process.env.PROFANITY_API_KEY 로만 접근):
  //   const res = await fetch("https://api.example.com/moderate", {
  //     method: "POST",
  //     headers: { Authorization: `Bearer ${process.env.PROFANITY_API_KEY}` },
  //     body: JSON.stringify({ text }),
  //   });
  //   return await res.json();
  return { flagged: false }; // 스텁
});
