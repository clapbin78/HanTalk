# HanTalk 작업 규칙 (Claude 필독)

## ⚡ 2026-07-14 Flutter 전환

iOS 네이티브(Swift) → **Flutter**로 전환됨. Swift 코드는 `ios-native` 브랜치에 보존
(미래의 네이티브 iOS SDK 뼈대 — 지우지 말 것). 태그: `swift-phase1-complete`.

## 코드 수정 워크플로 — 항상 이 순서로

함수/변수를 추가·변경하는 등 코드 수정이 있으면 **반드시**:

1. **아키텍처·MVVM 점검 먼저**: `ARCHITECTURE.md` 규칙에 어긋나지 않는지 확인
   - 의존 방향은 안쪽(core)으로만, core는 순수 Dart (flutter/firebase/DB import 금지)
   - View/ViewModel은 UseCase만 호출 (Repository 직접 접근 금지)
   - 새 데이터 접근 = Repository 추상(core) → 구현(data) → UseCase → ViewModel 순서
   - `bash scripts/archcheck.sh`로 자동 검증
2. 점검 통과 후에만 빌드/테스트:
   - `.build-request` 파일에 `test` / `analyze` / `app` 써서 생성
   - 결과: `scripts/build-status.txt`, 로그: `scripts/build-latest.log`
   - 사용자가 `bash ~/HanTalk/scripts/autobuild.sh`를 켜둔 상태여야 함

## 권한 사용 원칙 (민감 — 반드시 준수)

- 화면 캡처·마우스 제어 등 컴퓨터 제어 권한은 **오직 이 프로젝트의 빌드/개발 작업에만** 사용
- 허용된 앱 외에는 보지도 조작하지도 않는다
- 다른 목적 사용은 절대 금지 (사용자가 명시적으로 강조한 사항)

## 저장소 원칙

- **모노레포 유지** (hanchat + hanchat_firebase + app 한 저장소). 물리 분리는 하지 않는다.
- pub.dev 정식 배포 시점에 `hanchat/`을 git subtree split으로 별도 저장소로 추출 —
  이를 위해 hanchat은 저장소 바깥을 참조하지 않게 유지 (자기완결성).
- 바탕화면 HanTalk 폴더 = 사용자의 옛 프로젝트 (건드리지 말 것)

## 연락처 이메일 (절대 규칙)

- 공개 문서·코드·정책의 연락 이메일은 **clapbin78@gmail.com 만 사용**
- clapbinbox@gmail.com 은 절대 쓰지 않는다 (발견 즉시 교체)

## 시크릿 (절대 규칙 — SECURITY.md 참고)

- API 키·관리자 비번은 앱/깃에 절대 두지 않는다. Cloud Function Secret에만.
- 키를 코드에 임시로 넣었더라도 **커밋/푸시 전 반드시 제거** (사용자 강조)
- `.gitignore`에 시크릿 패턴 등록됨 (*.env, *secret*, *.key, GoogleService-Info.plist 등)

## 프로젝트 요약

- `hanchat/` = pub.dev 배포용 Flutter 채팅 SDK (core/data/ui), `app/` = 한톡 껍데기 앱
- 서버 = 우체통 (Firebase us-central1 권장, ChatTransport로 교체 가능):
  ephemeral(24h) 기본, retain(n일) 옵션
- 그림/이모티콘 = 획 벡터 JSON (Swift 버전과 포맷 호환 유지 — 크로스플랫폼 전제)
- 피처 플래그: paidEmoticonsEnabled=false, aiAssistantEnabled=false (로직·테스트는 상시 유지)
- 임티샵 = 중앙 서버 공유 갤러리: 사용(둘러보기·받기·전송)은 전 앱 기본 제공,
  업로드/판매는 유료 옵션 — 서버가 appId로 licenses/{appId} 결제 확인해야만 UI 노출
  (클라 플래그만으로 불가, firestore.rules에서 이중 강제)
- 번역 = 핵심 기능: 기본 ML Kit 온디바이스, TranslationService 주입 시 AI 번역 (Phase 4)
- 검증 실패 메시지는 l10n 키로 throw (`error.emptyMessage` 등) → UI에서 번역
- 규제: COMPLIANCE.md (EU 기준선, 4개국 출시: 미국→유럽→한국→일본)
- 약관/개인정보 문서는 앱 소유 (docs/ → clapbin78.github.io/HanTalk)
- 세로 모드 전용, iPhone/iPad/Android 폰·태블릿
- 웹뷰는 항상 인앱(webview_flutter — WKWebView/Android WebView, 주소창 미노출)
- **메시지 수정/삭제/취소 없음** = 제품 결정(문자 감성). 나중에 추가할 땐:
  MessageContent(sealed)에 Control 케이스 추가 → SyncEngine에서 분기 → UI 반영 순.
  현재 구조가 이 확장을 전제로 설계돼 있음 (봉투 프로토콜·sealed class)
- 기기 설치·체험은 `flutter run --release`, 개발(핫리로드)은 debug+F5
- **hanchat에 의존성(패키지) 추가 시 app도 `flutter pub get` 필수** (안 하면 app 빌드
  "Couldn't resolve package" 에러). autobuild가 test 모드에서 app pub get도 함께 수행.
  네이티브 플러그인 추가 시엔 `cd app && flutter clean && flutter pub get`
