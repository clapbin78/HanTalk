import SwiftUI
import Observation
import HanChatCore
import HanChatData

@Observable @MainActor
final class ChatRoomViewModel {
    private let client: HanChatClient
    private let roomID: String
    private var observation: Task<Void, Never>?

    var messages: [Message] = []
    var friends: [Friend] = []
    var inputText = ""
    var errorMessage: String?

    init(client: HanChatClient, roomID: String) {
        self.client = client
        self.roomID = roomID
    }

    func startObserving() {
        guard observation == nil else { return }
        observation = Task { [weak self, client, roomID] in
            for await messages in client.observeMessages(roomID: roomID) {
                self?.messages = messages
            }
        }
        Task { friends = (try? await client.getFriends()) ?? [] }
    }

    func stopObserving() {
        observation?.cancel()
        observation = nil
    }

    func sendText() async {
        let text = inputText
        inputText = ""
        do {
            try await client.sendMessage(.text(text), roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDrawing(_ payload: DrawingPayload) async {
        do {
            try await client.sendMessage(.drawing(payload), roomID: roomID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func senderName(for message: Message, myID: String) -> String? {
        guard message.senderID != myID else { return nil }
        return friends.first { $0.id == message.senderID }?.displayName ?? "알 수 없음"
    }
}

struct ChatRoomView: View {
    let client: HanChatClient
    let me: User
    let room: ChatRoom

    @State private var viewModel: ChatRoomViewModel
    @State private var showDrawingSheet = false
    @Environment(\.hanChatTheme) private var theme

    init(client: HanChatClient, me: User, room: ChatRoom) {
        self.client = client
        self.me = me
        self.room = room
        _viewModel = State(initialValue: ChatRoomViewModel(client: client, roomID: room.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        retentionNotice
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isMine: message.senderID == me.id,
                                senderName: room.kind == .group
                                    ? viewModel.senderName(for: message, myID: me.id)
                                    : nil,
                                theme: theme
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            inputBar
        }
        .navigationTitle(room.kind == .group ? (room.name ?? "단톡방") : "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDrawingSheet) {
            DrawingCanvasView { payload in
                showDrawingSheet = false
                Task { await viewModel.sendDrawing(payload) }
            }
        }
        .onAppear { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }

    private var retentionNotice: some View {
        Text("⏳ 메시지는 24시간 뒤 자동으로 사라져요")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                showDrawingSheet = true
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.title3)
            }

            TextField("메시지 입력", text: Bindable(viewModel).inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())

            Button {
                Task { await viewModel.sendText() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - 말풍선

struct MessageBubbleView: View {
    let message: Message
    let isMine: Bool
    let senderName: String?   // 단톡방에서 상대 메시지에만 표시
    let theme: HanChatTheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 48); metadata }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if let senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                bubbleContent
            }
            if !isMine { metadata; Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isMine ? theme.myBubble : theme.otherBubble,
                    in: RoundedRectangle(cornerRadius: 16)
                )
        case .drawing(let payload):
            // 그림 메시지: 탭하면 그리는 과정을 처음부터 재생
            DrawingReplayView(payload: payload)
                .frame(width: 200, height: 200 * payload.canvasSize.height / max(payload.canvasSize.width, 1))
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray4)))
        }
    }

    private var metadata: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if isMine && message.deliveryState == .sending {
                Text("전송 중").font(.caption2).foregroundStyle(.secondary)
            }
            if isMine && message.deliveryState == .failed {
                Text("실패").font(.caption2).foregroundStyle(.red)
            }
            Text(message.sentAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
