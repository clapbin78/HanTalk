# 한톡 보안 원칙

## 시크릿(비밀번호·API 키)은 절대 앱/깃에 두지 않는다 ★

- **관리자 비밀번호**: Firebase Secret Manager(`ADMIN_PASSWORD`)에만 저장.
  앱은 입력값을 `unlockAdmin` Cloud Function에 보내 **서버에서 검증**받고 토큰만 받는다.
- **외부 API 키(향후)**: 현재 사용하는 외부 API는 없음. 나중에 키가 필요한 API를 쓰면
  앱에 키를 넣지 말고 프록시 Function이 대신 호출 (패턴은 `functions/admin.js` 하단 주석).
  키는 서버 시크릿에만 존재.
- **왜?** 앱은 디컴파일하면 문자열이 다 보이고, 깃은 한 번 커밋하면 히스토리에 영원히 남는다.

### 깃 유출 방지 (이중 안전망)
1. `.gitignore`에 시크릿 패턴 등록: `*.env`, `**/secrets.dart`, `**/*secret*`,
   `**/*.key`, `GoogleService-Info.plist`, `google-services.json`
2. 키는 코드에 하드코딩하지 말고 **항상 Function 경유**. 실수로라도 앱 코드에
   키를 적었다면 커밋 전 반드시 제거 (사용자 규칙).

### 시크릿 등록 방법
```bash
firebase functions:secrets:set ADMIN_PASSWORD      # 관리자 비번
firebase functions:secrets:set PROFANITY_API_KEY   # 외부 API 키
```

## 관리자 모드
- 진입: 설정 → 앱 정보 10회 탭 → 비밀번호 입력 → 서버 검증 → 토큰 발급
- 세션: 앱 실행 중에만 메모리 유지 (재시작 시 해제)
- 확장: 관리자 기능이 늘어도 발급된 토큰 하나로 게이트 (AdminService/AdminSession)
- 현재 관리자 기능: 공지사항·FAQ 글쓰기

## 채팅 보안 (이미 확보)
- 채팅 내용 서버 미보관 (전달 즉시 삭제) → 유출 시에도 훔칠 대화가 없음
- 전화번호 해시화(SHA-256), 친구목록 기기에만 저장
- TLS(Firebase 기본)

## 로드맵 (Phase 2~)
1. 익명 인증 → 전화번호 인증 + Firestore 규칙 강화(내 우편함만 읽기)
2. E2E 암호화 (X25519 + AES-GCM) — 우체통 모델과 호환, 운영자도 못 읽음
3. 로컬 DB 암호화(SQLCipher), 인증서 피닝, 루팅/탈옥 감지 (사용자 증가 후)
