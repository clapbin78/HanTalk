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
                        L.noEmoticonsTitle,
                        systemImage: "face.smiling",
                        description: Text(L.noEmoticonsSubtitle)
                    )
                }
            }
            .navigationTitle(L.tabEmoticons)
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
                L.notice,
                isPresented: .init(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button(L.ok, role: .cancel) {}
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
        if owned { return L.owned }
        // 🚩 유료 가격표 — paidEmoticonsEnabled가 켜지기 전엔 모두 무료라 L.getFree만 보임
        if paidEnabled && !emoticon.isFree {
            return L.priceTag(emoticon.price)
        }
        return L.getFree
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
                    Section(L.name) {
                        TextField(L.emoticonNamePlaceholder, text: $name)
                    }
                    // 🚩 유료 가격 입력 — Phase 3에서 paidEmoticonsEnabled로 노출
                    if viewModel.paidEnabled {
                        Section(L.priceSection) {
                            TextField("0", text: $priceText)
                                .keyboardType(.numberPad)
                        }
                    }
                    Section {
                        Text(L.uploadDisclosure)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(L.uploadToGallery)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L.cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            upload(payload)
                        } label: {
                            if isUploading { ProgressView() } else { Text(L.upload) }
                        }
                        .disabled(name.isEmpty || isUploading)
                    }
                }
            }
        } else {
            DrawingCanvasView(sendButtonTitle: L.next) { drawn in
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
