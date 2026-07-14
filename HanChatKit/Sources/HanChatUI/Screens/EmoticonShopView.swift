import SwiftUI
import Observation
import HanChatCore
import HanChatData

@Observable @MainActor
final class EmoticonShopViewModel {
    private let client: HanChatClient

    var gallery: [Emoticon] = []
    var ownedIDs: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    /// 🚩 유료 기능 노출 여부 — Phase 3에서 configuration으로 켠다
    var paidEnabled: Bool { client.configuration.paidEmoticonsEnabled }

    init(client: HanChatClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            gallery = try await client.browseEmoticons()
            ownedIDs = Set(try await client.getMyEmoticons().map(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acquire(_ emoticon: Emoticon) async {
        do {
            _ = try await client.acquireEmoticon(emoticon)
            ownedIDs.insert(emoticon.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(name: String, payload: DrawingPayload, price: Int) async -> Bool {
        do {
            _ = try await client.uploadEmoticon(name: name, payload: payload, price: price)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// 이모티콘 갤러리 (지금은 전부 무료 공개 — 유료 UI는 플래그 뒤에 준비됨)
struct EmoticonShopView: View {
    let client: HanChatClient

    @State private var viewModel: EmoticonShopViewModel
    @State private var showUploadFlow = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    init(client: HanChatClient) {
        self.client = client
        _viewModel = State(initialValue: EmoticonShopViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.gallery) { emoticon in
                        EmoticonCard(
                            emoticon: emoticon,
                            owned: viewModel.ownedIDs.contains(emoticon.id),
                            paidEnabled: viewModel.paidEnabled
                        ) {
                            Task { await viewModel.acquire(emoticon) }
                        }
                    }
                }
                .padding()
            }
            .overlay {
                if viewModel.gallery.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "아직 이모티콘이 없어요",
                        systemImage: "face.smiling",
                        description: Text("첫 이모티콘을 그려서 올려보세요!")
                    )
                }
            }
            .navigationTitle("이모티콘")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUploadFlow = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showUploadFlow) {
                EmoticonUploadFlow(viewModel: viewModel)
            }
            .alert(
                "알림",
                isPresented: .init(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}

// MARK: - 카드

private struct EmoticonCard: View {
    let emoticon: Emoticon
    let owned: Bool
    let paidEnabled: Bool
    let onAcquire: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            DrawingThumbnailView(payload: emoticon.payload)
                .frame(height: 110)

            VStack(spacing: 2) {
                Text(emoticon.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(emoticon.creatorNickname)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                onAcquire()
            } label: {
                Text(buttonTitle)
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(owned)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var buttonTitle: String {
        if owned { return "보관함에 있음" }
        // 🚩 유료 가격표 — paidEmoticonsEnabled가 켜지기 전엔 모두 무료라 "받기"만 보임
        if paidEnabled && !emoticon.isFree {
            return "₩\(emoticon.price)"
        }
        return "받기"
    }
}

/// 정지 상태 썸네일 (갤러리 목록용 — 재생 없이 완성본만)
struct DrawingThumbnailView: View {
    let payload: DrawingPayload

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / max(payload.canvasSize.width, 1)
            let scaleY = size.height / max(payload.canvasSize.height, 1)
            let scale = min(scaleX, scaleY)
            for stroke in payload.strokes {
                guard let first = stroke.points.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x * scale, y: first.y * scale))
                for point in stroke.points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * scale, y: point.y * scale))
                }
                context.stroke(
                    path,
                    with: .color(Color(hex: stroke.colorHex)),
                    style: StrokeStyle(
                        lineWidth: stroke.width * scale,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }
    }
}

// MARK: - 업로드 플로우 (그림판 재사용 → 이름 입력)

private struct EmoticonUploadFlow: View {
    @Bindable var viewModel: EmoticonShopViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var payload: DrawingPayload?
    @State private var name = ""
    @State private var priceText = ""
    @State private var isUploading = false

    var body: some View {
        if let payload {
            NavigationStack {
                Form {
                    Section {
                        DrawingThumbnailView(payload: payload)
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                    }
                    Section("이름") {
                        TextField("예: 두근두근", text: $name)
                    }
                    // 🚩 유료 가격 입력 — Phase 3에서 paidEmoticonsEnabled로 노출
                    if viewModel.paidEnabled {
                        Section("가격 (원, 0 = 무료)") {
                            TextField("0", text: $priceText)
                                .keyboardType(.numberPad)
                        }
                    }
                    Section {
                        Text("올리면 모든 사용자에게 공개되고, 누구나 채팅에서 쓸 수 있어요. 저작권은 만든 사람(나)에게 있어요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("갤러리에 올리기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            upload(payload)
                        } label: {
                            if isUploading { ProgressView() } else { Text("올리기") }
                        }
                        .disabled(name.isEmpty || isUploading)
                    }
                }
            }
        } else {
            DrawingCanvasView(sendButtonTitle: "다음") { drawn in
                payload = drawn
            }
        }
    }

    private func upload(_ payload: DrawingPayload) {
        isUploading = true
        Task {
            let price = viewModel.paidEnabled ? (Int(priceText) ?? 0) : 0
            if await viewModel.upload(name: name, payload: payload, price: price) {
                dismiss()
            }
            isUploading = false
        }
    }
}
