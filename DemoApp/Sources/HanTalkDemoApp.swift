import SwiftUI
import HanChatData
import HanChatUI
// import HanChatFirebase   // Firebase 전환 시
// import FirebaseCore

/// 껍데기 데모 앱 — SDK 사용법 전체가 이 파일 하나에 담겨 있다.
@main
struct HanTalkDemoApp: App {

    init() {
        // ── 데모 모드: 서버 없이 실행 (봇이 답장해 줌) ─────────────────
        // 연락처 매칭 테스트: 아래 번호를 본인 연락처에 저장해 보세요.
        let transport = InMemoryChatTransport(seedFakeUsers: [
            (nickname: "김철수", phoneNumber: "010-1111-2222"),
            (nickname: "이영희", phoneNumber: "010-3333-4444"),
        ])

        // ── Firebase 모드로 전환하려면 위를 지우고: ──────────────────
        // FirebaseApp.configure()
        // let transport = FirebaseChatTransport()

        do {
            // 약관·개인정보처리방침은 SDK가 아니라 이 껍데기 앱의 소유물 (docs/ 폴더 → GitHub Pages)
            // 다른 앱에 SDK를 붙일 땐 그 앱의 약관 URL을 넣거나, 자체 동의 플로우가 있으면 nil.
            try HanChat.configure(HanChatConfiguration(
                transport: transport,
                localRetention: .oneDay,   // 기기 저장 메시지 24시간 자동삭제
                privacyPolicyURL: URL(string: "https://<깃헙아이디>.github.io/hantalk-policy/privacy.html"),
                termsOfServiceURL: URL(string: "https://<깃헙아이디>.github.io/hantalk-policy/terms.html"),
                serviceName: "한톡",
                requestsAppTracking: false // 광고/추적 SDK 없음 → ATT 요청 안 함
            ))
        } catch {
            fatalError("HanChat 초기화 실패: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HanChatRootView()
                .tint(Color(red: 0.96, green: 0.77, blue: 0.0))
        }
    }
}
