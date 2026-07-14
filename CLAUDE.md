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

## 프로젝트 요약

- `hanchat/` = pub.dev 배포용 Flutter 채팅 SDK (core/data/ui), `app/` = 한톡 껍데기 앱
- 서버 = 우체통 (Firebase us-central1 권장, ChatTransport로 교체 가능):
  ephemeral(24h) 기본, retain(n일) 옵션
- 그림/이모티콘 = 획 벡터 JSON (Swift 버전과 포맷 호환 유지 — 크로스플랫폼 전제)
- 피처 플래그: paidEmoticonsEnabled=false, aiAssistantEnabled=false (로직·테스트는 상시 유지)
- 번역 = 핵심 기능: 기본 ML Kit 온디바이스, TranslationService 주입 시 AI 번역 (Phase 4)
- 검증 실패 메시지는 l10n 키로 throw (`error.emptyMessage` 등) → UI에서 번역
- 규제: COMPLIANCE.md (EU 기준선, 4개국 출시: 미국→유럽→한국→일본)
- 약관/개인정보 문서는 앱 소유 (docs/ → clapbin78.github.io/HanTalk)
- 세로 모드 전용, iPhone/iPad/Android 폰·태블릿
