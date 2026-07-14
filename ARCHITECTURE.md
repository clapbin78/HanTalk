# HanChatKit 아키텍처 규칙

Clean Architecture + MVVM. 이 문서의 규칙은 `scripts/archcheck.sh`가 자동 검사하며,
빌드 스크립트가 매 빌드 전에 실행한다.

## 레이어와 의존 방향 (항상 안쪽으로만)

```
HanChatUI ──────► HanChatCore ◄────── HanChatData ◄────── HanChatFirebase
(View·ViewModel)   (Entity·UseCase·      (SwiftData·          (ChatTransport
                    Repository 프로토콜)    Repository 구현)       Firebase 구현)
```

## 규칙

1. **Core는 순수 Swift.** Foundation 외 어떤 프레임워크도 import하지 않는다.
   SwiftUI/SwiftData/Firebase/Contacts 전부 금지. 그래서 어디든 이식 가능하다.
2. **Core는 바깥을 모른다.** Data/UI/Firebase 모듈명이 Core 소스에 등장하면 위반.
3. **Data는 UI와 백엔드 구현을 모른다.** SwiftData는 허용(로컬 저장 담당),
   Firebase는 금지 — 백엔드는 `ChatTransport` 프로토콜 뒤에 숨는다.
4. **UI는 특정 백엔드를 모른다.** `HanChatConfiguration.transport`로 주입받을 뿐.
5. **View/ViewModel은 UseCase만 호출한다.** Repository 직접 접근 금지.
   조회·구독도 `GetFriendsUseCase`, `ObserveMessagesUseCase` 등으로 감싼다.

## MVVM 체크리스트 (새 화면 추가 시)

- View는 상태 표시와 사용자 입력 전달만. 비즈니스 로직 금지.
- ViewModel은 `@Observable @MainActor`, UseCase만 호출, UIKit/SwiftUI 타입 비보유
  (Color 등 UI 타입은 View/Theme에 둔다).
- 검증·규칙(빈 메시지 금지, 단톡방 최소 인원 등)은 UseCase에 둔다.
- 새 데이터 접근이 필요하면: Repository 프로토콜(Core) → 구현(Data) → UseCase(Core) → ViewModel 순으로 추가.

## 검사 실행

```bash
bash scripts/archcheck.sh
```
