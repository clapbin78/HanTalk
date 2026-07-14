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
            Text(L.welcomeTitle(configuration.serviceName))
                .font(.title2.bold())
            Text(L.welcomeSubtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()

            VStack(spacing: 12) {
                if let termsURL = configuration.termsOfServiceURL {
                    consentRow(
                        isOn: $agreedTerms,
                        title: L.agreeTerms,
                        link: PolicyLink(title: L.terms, url: termsURL)
                    )
                }
                if let privacyURL = configuration.privacyPolicyURL {
                    consentRow(
                        isOn: $agreedPrivacy,
                        title: L.agreePrivacy,
                        link: PolicyLink(title: L.privacyPolicy, url: privacyURL)
                    )
                }
            }
            .padding(.horizontal)

            Button(action: onNext) {
                Text(L.agreeAndStart)
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
            Button(L.view) { presentedPolicy = link }
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
                TextField(L.nickname, text: $nickname)
                TextField(L.phonePlaceholder, text: $phoneNumber)
                    .keyboardType(.phonePad)
            } header: {
                Text(L.profile)
            } footer: {
                Text(L.phonePrivacyFooter)
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
                    Text(L.register)
                }
            }
            .disabled(nickname.isEmpty || phoneNumber.count < 10 || isSubmitting)
        }
        .navigationTitle(L.createProfile)
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
            Text(L.notifTitle)
                .font(.title2.bold())
            Text(L.notifSubtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()

            Button {
                Task {
                    _ = await permissions.requestNotifications()
                    onFinish()
                }
            } label: {
                Text(L.enableNotifications).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(L.maybeLater, action: onFinish)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
    }
}
