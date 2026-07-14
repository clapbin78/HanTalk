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
                .tabItem { Label(L.tabFriends, systemImage: "person.2.fill") }

            ChatListView(client: client, me: me)
                .tabItem { Label(L.tabChats, systemImage: "message.fill") }

            EmoticonShopView(client: client)
                .tabItem { Label(L.tabEmoticons, systemImage: "face.smiling.inverse") }

            SettingsView(client: client, me: me)
                .tabItem { Label(L.tabSettings, systemImage: "gearshape.fill") }
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
                Section(L.myProfile) {
                    LabeledContent(L.nickname, value: me.nickname)
                }
                Section(L.tabChats) {
                    Toggle(L.drawingReplayToggle, isOn: $drawingReplayEnabled)
                    Text(L.drawingReplayFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(L.retentionSection) {
                    LabeledContent(L.autoDelete, value: retentionDescription)
                    Text(L.retentionFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                // 약관 URL이 주입된 경우에만 표시 (호스트 앱이 자체 약관을 쓰면 이 섹션은 안 보임)
                if client.configuration.hasPolicies {
                    Section(L.policiesSection) {
                        if let termsURL = client.configuration.termsOfServiceURL {
                            Button(L.terms) {
                                presentedPolicy = PolicyItem(title: L.terms, url: termsURL)
                            }
                        }
                        if let privacyURL = client.configuration.privacyPolicyURL {
                            Button(L.privacyPolicy) {
                                presentedPolicy = PolicyItem(title: L.privacyPolicy, url: privacyURL)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.tabSettings)
            .sheet(item: $presentedPolicy) { policy in
                PolicySheet(title: policy.title, url: policy.url)
            }
        }
    }

    private var retentionDescription: String {
        switch client.configuration.localRetention {
        case .keepForever: return L.never
        case .expireAfter(let seconds): return L.afterHours(Int(seconds / 3600))
        }
    }
}
