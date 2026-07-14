import SwiftUI
import HanChatCore
#if canImport(Translation)
import Translation
#endif

// MARK: - 어디든 붙이는 인라인 번역 텍스트
//
// 사용자가 원한 UX: 텍스트를 꾹 눌러 "번역"을 누르면 **그 자리에서 번역본으로 교체**.
// (애플 기본 바텀시트 UI 사용 안 함 — TranslationSession API를 직접 호출)
//
// 번역 엔진 우선순위:
// 1. HanChatConfiguration.translationService 주입 시 → 그 서비스 (Phase 4: AI 번역)
// 2. 없으면 → iOS 18+ 시스템 온디바이스 번역 (무료, 오프라인, 서버 비용 0)
// 3. iOS 17 + 서비스 없음 → 번역 메뉴 미노출
//
// 메시지·닉네임·방 이름 등 어떤 Text 자리에든 그대로 쓸 수 있다.

struct TranslatableText: View {
    let text: String

    @Environment(\.hanChatTranslate) private var translateUseCase
    @State private var translated: String?
    @State private var isTranslating = false
    @State private var pendingSystemRequest: String?

    var body: some View {
        Group {
            if let translated {
                VStack(alignment: .leading, spacing: 2) {
                    Text(translated)
                    Label(L.translatedBadge, systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
            } else {
                Text(text)
                    .opacity(isTranslating ? 0.4 : 1)
            }
        }
        .contextMenu {
            if translated != nil {
                Button {
                    translated = nil
                } label: {
                    Label(L.showOriginal, systemImage: "arrow.uturn.backward")
                }
            } else if canTranslate {
                Button {
                    startTranslation()
                } label: {
                    Label(L.translate, systemImage: "globe")
                }
            }
        }
        .modifier(SystemTranslationModifier(request: $pendingSystemRequest, result: $translated))
        .onChange(of: pendingSystemRequest) { _, newValue in
            if newValue == nil { isTranslating = false }
        }
    }

    private var canTranslate: Bool {
        if translateUseCase != nil { return true }
        if #available(iOS 18.0, *) { return true }
        return false
    }

    private func startTranslation() {
        // 1순위: 주입된 번역 서비스 (UseCase 경유 — MVVM 규칙 유지)
        if let translateUseCase {
            isTranslating = true
            Task {
                translated = try? await translateUseCase(text)
                isTranslating = false
            }
            return
        }
        // 2순위: 시스템 온디바이스 번역
        isTranslating = true
        pendingSystemRequest = text
    }
}

// MARK: - 시스템 번역 (iOS 18) — 저버전에서는 no-op

private struct SystemTranslationModifier: ViewModifier {
    @Binding var request: String?
    @Binding var result: String?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(SystemTranslationModifier18(request: $request, result: $result))
        } else {
            content
        }
    }
}

@available(iOS 18.0, *)
private struct SystemTranslationModifier18: ViewModifier {
    @Binding var request: String?
    @Binding var result: String?
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, newValue in
                guard newValue != nil else { return }
                // 첫 요청은 설정 생성, 이후엔 invalidate로 세션 재가동
                if configuration == nil {
                    configuration = TranslationSession.Configuration()
                } else {
                    configuration?.invalidate()
                }
            }
            .translationTask(configuration) { session in
                guard let text = request else { return }
                let response = try? await session.translate(text)
                result = response?.targetText ?? result
                request = nil
            }
    }
}

// MARK: - 환경 주입 (컴포지션 루트 → 뷰 트리)

struct HanChatTranslateKey: EnvironmentKey {
    static let defaultValue: TranslateTextUseCase? = nil
}

extension EnvironmentValues {
    var hanChatTranslate: TranslateTextUseCase? {
        get { self[HanChatTranslateKey.self] }
        set { self[HanChatTranslateKey.self] = newValue }
    }
}
