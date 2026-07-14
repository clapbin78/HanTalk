import SwiftUI
import Observation
import HanChatCore
import HanChatData

@Observable @MainActor
final class ChatListViewModel {
    private let client: HanChatClient
    private var observation: Task<Void, Never>?

    var rooms: [ChatRoom] = []
    var friends: [Friend] = []

    init(client: HanChatClient) {
        self.client = client
    }

    func startObserving() {
        guard observation == nil else { return }
        observation = Task { [weak self, client] in
            for await rooms in client.observeRooms() {
                self?.rooms = rooms
            }
        }
        Task { friends = (try? await client.getFriends()) ?? [] }
    }

    func stopObserving() {
        observation?.cancel()
        observation = nil
    }

    func createGroup(name: String, memberIDs: [String], myID: String) async -> ChatRoom? {
        try? await client.createRoom.group(name: name, memberIDs: [myID] + memberIDs)
    }

    /// 1:1 방 제목 = 상대 이름
    func title(for room: ChatRoom, myID: String) -> String {
        if room.kind == .group { return room.name ?? "단톡방" }
        let otherID = room.memberIDs.first { $0 != myID }
        return friends.first { $0.id == otherID }?.displayName ?? "알 수 없음"
    }
}

struct ChatListView: View {
    let client: HanChatClient
    let me: User

    @State private var viewModel: ChatListViewModel
    @State private var showNewGroupSheet = false
    @State private var pushedRoom: ChatRoom?

    init(client: HanChatClient, me: User) {
        self.client = client
        self.me = me
        _viewModel = State(initialValue: ChatListViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            List(viewModel.rooms) { room in
                Button {
                    pushedRoom = room
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(name: viewModel.title(for: room, myID: me.id))
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(viewModel.title(for: room, myID: me.id))
                                    .font(.headline)
                                if room.kind == .group {
                                    Text("\(room.memberIDs.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(room.lastMessagePreview ?? "대화를 시작해 보세요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if let date = room.lastMessageAt {
                            Text(date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .overlay {
                if viewModel.rooms.isEmpty {
                    ContentUnavailableView(
                        "채팅이 없어요",
                        systemImage: "message",
                        description: Text("친구 탭에서 친구를 눌러 대화를 시작하세요.")
                    )
                }
            }
            .navigationTitle("채팅")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewGroupSheet = true
                    } label: {
                        Image(systemName: "plus.message")
                    }
                }
            }
            .navigationDestination(item: $pushedRoom) { room in
                ChatRoomView(client: client, me: me, room: room)
            }
            .sheet(isPresented: $showNewGroupSheet) {
                NewGroupSheet(viewModel: viewModel, me: me) { room in
                    showNewGroupSheet = false
                    pushedRoom = room
                }
            }
            .onAppear { viewModel.startObserving() }
            .onDisappear { viewModel.stopObserving() }
        }
    }
}

/// 단톡방 생성 시트: 이름 + 친구 2명 이상 선택
private struct NewGroupSheet: View {
    @Bindable var viewModel: ChatListViewModel
    let me: User
    let onCreated: (ChatRoom) -> Void

    @State private var groupName = ""
    @State private var selectedIDs: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("방 이름") {
                    TextField("예: 불금 모임 🍻", text: $groupName)
                }
                Section("초대할 친구 (2명 이상)") {
                    ForEach(viewModel.friends) { friend in
                        Button {
                            if selectedIDs.contains(friend.id) {
                                selectedIDs.remove(friend.id)
                            } else {
                                selectedIDs.insert(friend.id)
                            }
                        } label: {
                            HStack {
                                Text(friend.displayName)
                                Spacer()
                                Image(systemName: selectedIDs.contains(friend.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("단톡방 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("만들기") {
                        Task {
                            if let room = await viewModel.createGroup(
                                name: groupName,
                                memberIDs: Array(selectedIDs),
                                myID: me.id
                            ) {
                                onCreated(room)
                            }
                        }
                    }
                    .disabled(groupName.isEmpty || selectedIDs.count < 2)
                }
            }
        }
    }
}
