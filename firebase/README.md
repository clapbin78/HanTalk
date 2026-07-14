# Firebase 셋업 (무료 Spark 플랜으로 시작 가능)

## 0. 리전 선택 ⚠️ 프로젝트 생성 시 한 번만 — 나중에 변경 불가!

**권장: `us-central1` (또는 미국 멀티리전 `nam5`)**

| 기준 | 미국 (us-central1) | 한국 (asia-northeast3 서울) |
|---|---|---|
| 전세계 사용자 평균 지연 | ✅ 유리 | 아시아 외 지역 불리 |
| AI API 연동 (OpenAI/Claude 등 미국 서버) | ✅ 서버간 왕복 최소 | 태평양 왕복 추가 |
| 한국 사용자 체감 | +100~150ms (푸시 기반 채팅이라 체감 미미) | ✅ 최저 지연 |
| 무료 할당량/요금 | 동일 | 동일 |

한톡은 ① 전세계 배포 목표 ② Phase 4 AI 기능(미국 리전 API) 계획이므로 미국 리전이 맞다.
채팅은 실시간 게임과 달리 100ms 차이를 사용자가 느끼기 어렵고,
서버가 "우체통"이라 지연은 전달 순간 한 번뿐이다.
(나중에 한국 사용자가 압도적으로 많아지면 그때 서울 리전 프로젝트로 이전을 검토 —
ChatTransport가 추상화돼 있어 클라이언트 코드는 안 바뀐다.)

> 참고: FCM 푸시 발송 함수(Cloud Functions)는 Blaze 플랜이 필요하지만,
> Blaze도 무료 할당량이 커서 초기엔 사실상 0원. 푸시 없이 시작하려면 함수 배포를 생략하면 된다
> (앱이 포그라운드일 때는 Firestore 리스너만으로 실시간 수신됨).

## 1. 프로젝트 생성
1. https://console.firebase.google.com → 프로젝트 추가
2. iOS 앱 등록 (번들 ID: 데모는 `com.hantalk.demo`)
3. `GoogleService-Info.plist` 다운로드 → `DemoApp/Resources/`에 추가

## 2. 활성화할 것
- **Authentication** → 익명 로그인 켜기 (Phase 2에서 전화번호 인증으로 교체 가능)
- **Firestore Database** → 프로덕션 모드로 생성 → `firestore.rules` 배포:
  ```bash
  firebase deploy --only firestore:rules
  ```

## 3. 서버 메시지 24시간 자동삭제 (TTL)
Firestore 콘솔 → TTL 정책 추가:
- 컬렉션 그룹: `envelopes`
- 필드: `expiresAt`

이러면 미수신 메시지도 서버에서 24시간 뒤 자동 삭제된다.
(수신된 메시지는 앱이 ack하는 순간 즉시 삭제됨 — 정상 흐름에서 서버에 채팅 내용이 남지 않는다.)

## 4. 푸시 (선택, Blaze 플랜)
```bash
cd functions && npm install firebase-functions firebase-admin
firebase deploy --only functions
```
Apple Developer 콘솔에서 APNs 키 발급 → Firebase 프로젝트 설정 → 클라우드 메시징에 업로드.
