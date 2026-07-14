/**
 * 관리자 모드 — Cloud Functions v2
 *
 * 원칙: 비밀번호·API 키는 앱에도 깃에도 절대 두지 않는다.
 *       Firebase Secret Manager에만 저장하고, 검증/호출은 서버에서만 한다.
 *
 * 배포 전 시크릿 등록:
 *   firebase functions:secrets:set ADMIN_PASSWORD
 *
 * ▶ 외부 API(키 필요)를 나중에 쓰게 되면: 앱에 키를 넣지 말고 이 파일에
 *   프록시 함수를 하나 추가해 서버에서 대신 호출한다. 패턴은 파일 하단 주석 참고.
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

// ─────────────────────────────────────────────────────────────
// 외부 API 프록시 패턴 (참고용 — 지금은 사용하는 외부 API 없음)
//
// 키가 필요한 외부 API를 쓰게 되면, 앱에 키를 넣지 말고 아래처럼
// 서버 함수가 대신 호출한다. 앱은 이 함수만 부르고 키는 서버 시크릿에만 존재.
//
//   firebase functions:secrets:set SOME_API_KEY
//
//   exports.callSomeApi = onCall({ secrets: ["SOME_API_KEY"] }, async (request) => {
//     const res = await fetch("https://api.example.com/endpoint", {
//       method: "POST",
//       headers: { Authorization: `Bearer ${process.env.SOME_API_KEY}` },
//       body: JSON.stringify(request.data),
//     });
//     return await res.json();
//   });
// ─────────────────────────────────────────────────────────────
