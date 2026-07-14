import SwiftUI
import HanChatCore
import HanChatData

/// 최초 설치 플로우: (약관 동의) → 프로필 등록 → 알림 권한 → (선택) ATT
/// 약관 URL이 주입되지 않았으면 동의 단계는 생략된다 — 호스트 앱이 자체 약관 플로우를 가진 경우.
struct OnboardingView: View {
    let client: HanChatClient
    let onComplete: () -> Void

    @StateObject private var permissions = PermissionCoordinator()
    @State private var step: Step

    enum Step { case consent, profile, notifications }

    init(client: HanChatClient, onComplete: @escaping () -> Void) {
        self.client = client
        self.onComplete = onComplete
        _step = State(initialValue: client.configuration.hasPolicies ? .consent : .profile)
    }

    var body: some View {
        NavigationStack {
            switch step {
            case .consent:
                ConsentStepView(configuration: client.configuration) {
                    step = .profile
                }
            case .profile:
                ProfileStepView(client: client) {
                    step = .notifications
                }
            case .notifications:
                NotificationStepView(permissions: permissions) {
                    Task {
                        // ATT는 추적 SDK를 쓸 때만 (기본 꺼짐)
                        await permissions.requestTrackingIfNeeded(
                            enabled: client.configuration.requestsAppTracking
                        )
                        onComplete()
                    }
                }
            }
        }
    }
}

// MARK: - 1. 약관 동의

private struct ConsentStepView: View {
    let configuration: HanChatConfiguration
    let onNext: () -> Void

    @State private var agreedTerms = false
    @State private var agreedPrivacy = false
    @State private var presentedPolicy: PolicyLink?

    struct PolicyLink: Identifiable {
        let id = UUID()
        let title: String
        let url: URL
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("💬").font(.system(size: 64))
            Text("\(configuration.serviceName)에 오신 걸 환영해요")
                .font(.title2.bold())
            Text("메시지는 서버에 남지 않고,\n기기에서도 24시간 뒤 사라져요.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()

            VStack(spacing: 12) {
                if let termsURL = configuration.termsOfServiceURL {
                    consentRow(
                        isOn: $agreedTerms,
                        title: "이용약관 동의 (필수)",
                        link: PolicyLink(title: "이용약관", url: termsURL)
                    )
                }
                if let privacyURL = configuration.privacyPolicyURL {
                    consentRow(
                        isOn: $agreedPrivacy,
                        title: "개인정보 수집·이용 동의 (필수)",
                        link: PolicyLink(title: "개인정보처리방침", url: privacyURL)
                    )
                }
            }
            .padding(.horizontal)

            Button(action: onNext) {
                Text("동의하고 시작하기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!(agreedTerms && agreedPrivacy))
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .sheet(item: $presentedPolicy) { policy in
            PolicySheet(title: policy.title, url: policy.url)
        }
    }

    private func consentRow(isOn: Binding<Bool>, title: String, link: PolicyLink) -> some View {
        HStack {
            Toggle(isOn: isOn) {
                Text(title).font(.subheadline)
            }
            .toggleStyle(CheckboxToggleStyle())
            Spacer()
            Button("보기") { presentedPolicy = link }
                .font(.subheadline)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                configuration.label
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 2. 프로필 등록

private struct ProfileStepView: View {
    let client: HanChatClient
    let onNext: () -> Void

    @State private var nickname = ""
    @State private var phoneNumber = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("닉네임", text: $nickname)
                TextField("전화번호 (예: 01012345678)", text: $phoneNumber)
                    .keyboardType(.phonePad)
            } header: {
                Text("프로필")
            } footer: {
                Text("전화번호 원본은 서버로 전송되지 않아요. 친구 찾기에는 암호화된 해시만 사용됩니다.")
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            Button {
                submit()
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("등록")
                }
            }
            .disabled(nickname.isEmpty || phoneNumber.count < 10 || isSubmitting)
        }
        .navigationTitle("프로필 만들기")
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await client.registerUser(nickname: nickname, phoneNumber: phoneNumber)
                await client.start()
                onNext()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

// MARK: - 3. 알림 권한

private struct NotificationStepView: View {
    @ObservedObject var permissions: PermissionCoordinator
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("새 메시지를 놓치지 마세요")
                .font(.title2.bold())
            Text("친구가 보낸 메시지가 도착하면 알려드려요.\n푸시에 메시지 내용은 담기지 않아요.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()

            Button {
                Task {
                    _ = await permissions.requestNotifications()
                    onFinish()
                }
            } label: {
                Text("알림 켜기").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("나중에 할게요", action: onFinish)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
    }
}
