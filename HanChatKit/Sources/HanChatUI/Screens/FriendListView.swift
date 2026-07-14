import SwiftUI
import Observation
import HanChatCore
import HanChatData

@Observable @MainActor
final class FriendListViewModel {
    private let client: HanChatClient
    private let permissions = PermissionCoordinator()

    var friends: [Friend] = []
    var candidates: [FriendCandidate] = []
    var selectedCandidateIDs: Set<String> = []
    var isSyncing = false
    var showCandidateSheet = false
    var errorMessage: String?

    init(client: HanChatClient) {
        self.client = client
    }

    func load() async {
        friends = (try? await client.getFriends()) ?? []
    }

    /// 연락처 동기화. mode == .all 이면 전부 자동 등록, .manual이면 선택 시트 표시.
    func syncContacts(mode: ContactSyncMode) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            guard await permissions.requestContacts() else {
                errorMessage = L.contactsPermissionNeeded
                return
            }
            let contacts = try await permissions.readContacts()
            let found = try await client.syncContacts.findCandidates(in: contacts)
            switch mode {
            case .all:
                _ = try await client.syncContacts.register(found)
                await load()
            case .manual:
                candidates = found
                selectedCandidateIDs = []
                showCandidateSheet = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func registerSelectedCandidates() async {
        let selection = candidates.filter { selectedCandidateIDs.contains($0.id) }
        do {
            _ = try await client.syncContacts.register(selection)
            showCandidateSheet = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 친구와 1:1 채팅 시작 → 방 반환
    func startDirectChat(with friend: Friend, myID: String) async -> ChatRoom? {
        try? await client.createRoom.direct(with: friend.id, myID: myID)
    }
}

struct FriendListView: View {
    let client: HanChatClient
    let me: User

    @State private var viewModel: FriendListViewModel
    @State private var pushedRoom: ChatRoom?

    init(client: HanChatClient, me: User) {
        self.client = client
        self.me = me
        _viewModel = State(initialValue: FriendListViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(L.myProfile, value: me.nickname)
                }
                Section(L.friendsCount(viewModel.friends.count)) {
                    if viewModel.friends.isEmpty {
                        Text(L.noFriendsYet)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.friends) { friend in
                        Button {
                            Task {
                                pushedRoom = await viewModel.startDirectChat(with: friend, myID: me.id)
                            }
                        } label: {
                            HStack {
                                AvatarView(name: friend.displayName)
                                VStack(alignment: .leading) {
                                    Text(friend.displayName)
                                    if friend.localName != nil, friend.localName != friend.nickname {
                                        Text(friend.nickname)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(L.tabFriends)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L.syncAllContacts) {
                            Task { await viewModel.syncContacts(mode: .all) }
                        }
                        Button(L.syncManualContacts) {
                            Task { await viewModel.syncContacts(mode: .manual) }
                        }
                    } label: {
                        if viewModel.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationDestination(item: $pushedRoom) { room in
                ChatRoomView(client: client, me: me, room: room)
            }
            .sheet(isPresented: Bindable(viewModel).showCandidateSheet) {
                CandidatePickerSheet(viewModel: viewModel)
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
        }
    }
}

/// 직접 선택 등록 시트 — 가입자 후보 중 체크한 사람만 친구로.
private struct CandidatePickerSheet: View {
    @Bindable var viewModel: FriendListViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.candidates) { candidate in
                Button {
                    if viewModel.selectedCandidateIDs.contains(candidate.id) {
                        viewModel.selectedCandidateIDs.remove(candidate.id)
                    } else {
                        viewModel.selectedCandidateIDs.insert(candidate.id)
                    }
                } label: {
                    HStack {
                        AvatarView(name: candidate.localName ?? candidate.nickname)
                        VStack(alignment: .leading) {
                            Text(candidate.localName ?? candidate.nickname)
                            Text(candidate.nickname)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: viewModel.selectedCandidateIDs.contains(candidate.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.tint)
                    }
                }
                .foregroundStyle(.primary)
            }
            .overlay {
                if viewModel.candidates.isEmpty {
                    ContentUnavailableView(
                        L.noCandidatesTitle,
                        systemImage: "person.slash",
                        description: Text(L.noCandidatesSubtitle)
                    )
                }
            }
            .navigationTitle(L.selectFriends)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.addSelected(viewModel.selectedCandidateIDs.count)) {
                        Task { await viewModel.registerSelectedCandidates() }
                    }
                    .disabled(viewModel.selectedCandidateIDs.isEmpty)
                }
            }
        }
    }
}

struct AvatarView: View {
    let name: String

    var body: some View {
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 40, height: 40)
            .overlay {
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
    }
}
