# HanTalk 작업 규칙 (Claude 필독)

## 코드 수정 워크플로 — 항상 이 순서로

함수/변수를 추가·변경하는 등 코드 수정이 있으면 **반드시**:

1. **아키텍처·MVVM 점검 먼저**: `ARCHITECTURE.md`의 규칙 5개에 어긋나지 않는지 확인
   - 의존 방향은 안쪽(Core)으로만, Core는 순수 Swift
   - View/ViewModel은 UseCase만 호출 (Repository 직접 접근 금지)
   - 새 데이터 접근 = Repository 프로토콜(Core) → 구현(Data) → UseCase → ViewModel 순서로 추가
   - `bash scripts/archcheck.sh`로 자동 검증
2. 점검 통과 후에만 빌드/테스트 진행:
   - `.build-request` 파일에 `build` / `test` / `demo` 써서 생성
   - 결과: `scripts/build-status.txt`, 로그: `scripts/build-latest.log`
   - 사용자가 `bash ~/HanTalk/scripts/autobuild.sh`를 켜둔 상태여야 함

## 권한 사용 원칙 (민감 — 반드시 준수)

- 화면 캡처·마우스 제어 등 컴퓨터 제어 권한은 **오직 이 프로젝트의 빌드/개발 작업에만** 사용
- 허용된 앱(Xcode, Finder) 외에는 보지도 조작하지도 않는다
- 다른 목적 사용은 절대 금지 (사용자가 명시적으로 강조한 사항)

## 프로젝트 요약

- 채팅 SDK(HanChatKit) + 껍데기 데모 앱. Clean Architecture + MVVM. iOS 17+, SwiftData, SwiftUI(+UIKit 래퍼)
- 서버 = 우체통(Firebase, 교체 가능): ephemeral(24h) 기본, retain(n일) 옵션
- 이모티콘 갤러리: 현재 전부 무료. 유료 판매 로직은 완성·테스트돼 있으나
  `paidEmoticonsEnabled=false`로 숨김 (Phase 3에서 켬)
- 약관/개인정보 문서는 껍데기 앱 소유 (docs/ → GitHub Pages, clapbin78.github.io/HanTalk)
- 배포: SPM 메인, CocoaPods는 2026-12-02 trunk read-only 전에 등록
