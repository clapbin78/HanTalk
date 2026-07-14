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
                privacyPolicyURL: URL(string: "https://clapbin78.github.io/HanTalk/privacy.html"),
                termsOfServiceURL: URL(string: "https://clapbin78.github.io/HanTalk/terms.html"),
                serviceName: "한톡",
                requestsAppTracking: false // 광고/추적 SDK 없음 → ATT 요청 안 함
            ))
        } catch {
            fatalError("HanChat 초기화 실패: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootWithSplash()
                .tint(Color(red: 0.96, green: 0.77, blue: 0.0))
        }
    }
}

/// 앱 로딩(스플래시) 화면 — SDK 초기화 동안 브랜드 노출 후 부드럽게 전환
private struct RootWithSplash: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            HanChatRootView()
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.77, blue: 0.0).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("💬").font(.system(size: 72))
                Text("한톡")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.black.opacity(0.85))
                Text("24시간 뒤 사라지는 대화")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.55))
            }
        }
    }
}
