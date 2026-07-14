import SwiftUI
import HanChatCore
import HanChatData

/// SDK가 제공하는 최상위 화면. 호스트 앱은 이 뷰 하나만 띄우면 된다.
public struct HanChatRootView: View {
    @State private var currentUser: User?
    @State private var isLoading = true
    @Environment(\.scenePhase) private var scenePhase

    private var client: HanChatClient { HanChat.requireClient() }

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if currentUser == nil {
                OnboardingView(client: client) {
                    Task { currentUser = try? await client.getCurrentUser() }
                }
            } else {
                MainTabView(client: client, me: currentUser!)
            }
        }
        .task {
            currentUser = try? await client.getCurrentUser()
            isLoading = false
        }
        .onChange(of: scenePhase) { _, phase in
            // 포그라운드 진입 시: 수신 재개 + 24시간 지난 메시지 정리
            if phase == .active {
                Task { await client.start() }
            }
        }
    }
}

struct MainTabView: View {
    let client: HanChatClient
    let me: User

    var body: some View {
        TabView {
            FriendListView(client: client, me: me)
                .tabItem { Label("친구", systemImage: "person.2.fill") }

            ChatListView(client: client, me: me)
                .tabItem { Label("채팅", systemImage: "message.fill") }

            SettingsView(client: client, me: me)
                .tabItem { Label("설정", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - 설정

struct SettingsView: View {
    let client: HanChatClient
    let me: User
    @State private var presentedPolicy: PolicyItem?
    @AppStorage("HanChatDrawingReplayEnabled") private var drawingReplayEnabled = true

    struct PolicyItem: Identifiable {
        let id = UUID()
        let title: String
        let url: URL
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("내 프로필") {
                    LabeledContent("닉네임", value: me.nickname)
                }
                Section("채팅") {
                    Toggle("그림 그리는 과정 재생", isOn: $drawingReplayEnabled)
                    Text("끄면 완성된 그림만 바로 표시돼요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("메시지 보관") {
                    LabeledContent("자동 삭제", value: retentionDescription)
                    Text("메시지는 서버에 저장되지 않으며, 이 기기에서도 위 기간이 지나면 자동으로 삭제됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                // 약관 URL이 주입된 경우에만 표시 (호스트 앱이 자체 약관을 쓰면 이 섹션은 안 보임)
                if client.configuration.hasPolicies {
                    Section("약관 및 정책") {
                        if let termsURL = client.configuration.termsOfServiceURL {
                            Button("이용약관") {
                                presentedPolicy = PolicyItem(title: "이용약관", url: termsURL)
                            }
                        }
                        if let privacyURL = client.configuration.privacyPolicyURL {
                            Button("개인정보처리방침") {
                                presentedPolicy = PolicyItem(title: "개인정보처리방침", url: privacyURL)
                            }
                        }
                    }
                }
            }
            .navigationTitle("설정")
            .sheet(item: $presentedPolicy) { policy in
                PolicySheet(title: policy.title, url: policy.url)
            }
        }
    }

    private var retentionDescription: String {
        switch client.configuration.localRetention {
        case .keepForever: return "안 함"
        case .expireAfter(let seconds): return "\(Int(seconds / 3600))시간 후"
        }
    }
}
