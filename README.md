# 한톡 (HanTalk) 💬

어떤 iOS 앱에도 붙는 채팅 솔루션. 메시지는 서버에 남지 않고, 기기에서도 24시간 뒤 사라진다.
그림을 그려 보내면 **그리는 과정이 그대로 재생**된다.

## 폴더 구조

```
HanTalk/
├── HanChatKit/          # SPM 패키지 (배포 대상)
│   ├── Sources/
│   │   ├── HanChatCore/       # Domain — Entity·UseCase·Repository 프로토콜 (의존성 0)
│   │   ├── HanChatData/       # SwiftData 로컬 저장 + Repository 구현 + 우체통 프로토콜
│   │   ├── HanChatFirebase/   # Firebase 어댑터 (교체 가능한 백엔드)
│   │   └── HanChatUI/         # SwiftUI 화면 + UIKit 래퍼 + 권한 온보딩
│   ├── Tests/
│   └── HanChatKit.podspec
├── DemoApp/             # 껍데기 데모 앱 (XcodeGen)
├── docs/                # 개인정보처리방침·이용약관 HTML → GitHub Pages
└── firebase/            # Firestore 규칙 + Cloud Functions (푸시, 24h 청소)
```

## 아키텍처

Clean Architecture + MVVM. 의존 방향은 항상 Domain 쪽으로만.

```
HanChatUI (View + ViewModel)
    ↓ UseCase 호출
HanChatCore (Entity · UseCase · Repository 프로토콜)   ← 순수 Swift
    ↑ 프로토콜 구현
HanChatData (SwiftData 로컬 + ChatTransport 프로토콜)
    ↑ ChatTransport 구현
HanChatFirebase │ InMemoryChatTransport │ 자체 서버 어댑터(직접 구현)
```

핵심 설계 — **서버는 DB가 아니라 우체통**:
1. 보내기: 로컬(SwiftData) 저장 → 수신자별 우편함 업로드
2. 받기: 우편함 구독 → 로컬 저장 → **서버에서 즉시 삭제(ack)**
3. 미수신분은 서버 TTL이 24시간 뒤 삭제, 기기 저장분도 24시간 뒤 자동삭제

보관 정책은 양쪽 다 옵션이다 (호스트 앱이 선택):

| 정책 | 기본값 (한톡) | 다른 앱에 붙일 때 |
|---|---|---|
| 서버 | `ServerRetention.ephemeral` (ack 즉시 삭제) | `.retain(days: 3)` — 일반 메신저처럼 n일 보관 |
| 기기 | `RetentionPolicy.oneDay` (24h 자동삭제) | `.keepForever` — 영구 보관 |

⚠️ `.retain`을 쓰면 그 앱의 개인정보처리방침에 서버 보관 기간을 반드시 명시할 것.
(한톡의 `docs/privacy.html`은 ephemeral 기준으로 작성되어 있음)

## 데모 앱 실행 (서버 불필요)

```bash
brew install xcodegen
cd DemoApp && xcodegen
open HanTalkDemo.xcodeproj
```

기본값은 `InMemoryChatTransport` — Firebase 없이 실행되고 "한톡봇"이 답장해 준다.
연락처 매칭 테스트: `010-1111-2222`(김철수)를 연락처에 저장한 뒤 친구 동기화.

Firebase 모드 전환은 `DemoApp/Sources/HanTalkDemoApp.swift` 주석과 `firebase/README.md` 참고.

## 호스트 앱에 붙이기

```swift
// 1. 앱 시작 시
try HanChat.configure(HanChatConfiguration(
    transport: FirebaseChatTransport(retention: .ephemeral), // 또는 .retain(days: 3)
    localRetention: .oneDay,                                 // 또는 .keepForever
    // 약관은 호스트 앱 소유 — nil이면 SDK가 동의 화면을 건너뜀
    // (기존 앱: 자체 약관에 채팅 조항만 추가하고 nil 유지)
    privacyPolicyURL: URL(string: "https://<아이디>.github.io/hantalk-policy/privacy.html"),
    termsOfServiceURL: URL(string: "https://<아이디>.github.io/hantalk-policy/terms.html")
))

// 2-a. SwiftUI
HanChatRootView()

// 2-b. UIKit
navigationController?.pushViewController(HanChatViewController(), animated: true)
```

호스트 앱 Info.plist에 필요한 키: `NSContactsUsageDescription` (필수),
`NSUserTrackingUsageDescription` (ATT 사용 시), `UIBackgroundModes: remote-notification` (푸시 사용 시).

## 정책 문서 배포 (GitHub Pages)

1. `docs/` 폴더를 GitHub 저장소에 push
2. 저장소 Settings → Pages → Source: `main` 브랜치 `/docs` 폴더
3. 발행된 URL을 `HanChatConfiguration`의 policy URL에 넣기
4. `privacy.html`의 "개인정보 보호책임자" 성명 채우기 ← **배포 전 필수**

## 배포

- **SPM (메인)**: GitHub에 `HanChatKit/`를 루트로 하는 저장소 push → 태그 → 끝
- **CocoaPods**: `pod trunk push HanChatKit.podspec`
  ⚠️ CocoaPods trunk는 **2026-12-02부터 read-only**. 등록할 거면 그 전에!

## 로드맵

- [x] Phase 1: 코어 아키텍처, 로컬 채팅, 데모 봇
- [ ] Phase 2: Firebase 운영 전환 (전화번호 인증, 보안 규칙 강화, 푸시)
- [ ] Phase 3: 이모티콘 샵 (벡터 그림 → 움직이는 이모티콘, 코인 IAP + 크리에이터 정산)
