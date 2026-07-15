import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'chat_room_page.dart';
import 'l10n.dart';
import 'profile_view_page.dart';
import 'root.dart';
import 'translatable_text.dart';

/// MVVM: ViewModel은 UseCase만 호출한다 (Repository 직접 접근 금지 — archcheck 감시).
class FriendsViewModel extends ChangeNotifier {
  final HanChatClient _client;

  List<Friend> friends = [];
  List<FriendCandidate> candidates = [];
  Set<String> selectedIds = {};
  bool syncing = false;
  String? errorKey;

  FriendsViewModel(this._client);

  Future<void> load() async {
    friends = await _client.getFriends();
    notifyListeners();
  }

  /// 연락처 동기화. [ContactSyncMode.all]=전부 자동, [ContactSyncMode.manual]=선택 시트.
  /// 반환: manual 모드에서 후보 시트를 띄워야 하면 true.
  Future<bool> syncContacts(ContactSyncMode mode) async {
    syncing = true;
    errorKey = null;
    notifyListeners();
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted) {
        errorKey = 'friends.permNeeded';
        return false;
      }
      final deviceContacts =
          await FlutterContacts.getAll(properties: {ContactProperty.phone});
      final contacts = [
        for (final c in deviceContacts)
          if (c.phones.isNotEmpty)
            DeviceContact(
              name: c.displayName ?? '',
              phoneNumbers: [for (final p in c.phones) p.number],
            ),
      ];
      final found = await _client.syncContacts.findCandidates(contacts);
      if (mode == ContactSyncMode.all) {
        await _client.syncContacts.register(found);
        await load();
        return false;
      }
      candidates = found;
      selectedIds = {};
      return true;
    } catch (e) {
      errorKey = e.toString();
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void toggleCandidate(String id) {
    selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id);
    notifyListeners();
  }

  Future<void> registerSelected() async {
    final selection = [
      for (final c in candidates)
        if (selectedIds.contains(c.id)) c,
    ];
    await _client.syncContacts.register(selection);
    await load();
  }

  Future<ChatRoom?> startDirectChat(Friend friend) async {
    final me = await _client.getCurrentUser();
    if (me == null) return null;
    return _client.createRoom.direct(friendId: friend.id, myId: me.id);
  }

  Future<void> block(String id) async {
    await _client.manageFriends.block(id);
    await load();
  }

  Future<void> hide(String id) async {
    await _client.manageFriends.hide(id);
    await load();
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final _vm = FriendsViewModel(HanChat.client)..load();

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        _maybeShowError(l10n);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('tab.friends')),
            actions: [
              _vm.syncing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: () => _showAddSheet(l10n),
                    ),
              const SettingsButton(),
            ],
          ),
          body: _vm.friends.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l10n.t('friends.empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                )
              : ListView(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n
                          .t('friends.count')
                          .replaceFirst('%d', '${_vm.friends.length}'),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                  for (final friend in _vm.friends)
                    ListTile(
                      // 아이콘 탭 → 상대 프로필 보기 (행 탭 → 채팅)
                      leading: GestureDetector(
                        onTap: () => openProfile(context,
                            userId: friend.id, fallbackName: friend.displayName),
                        child: _Avatar(name: friend.displayName),
                      ),
                      title: TranslatableText(friend.displayName),
                      subtitle: friend.localName != null &&
                              friend.localName != friend.nickname
                          ? Text(friend.nickname,
                              style: const TextStyle(fontSize: 12))
                          : null,
                      onTap: () async {
                        final room = await _vm.startDirectChat(friend);
                        if (room != null && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => ChatRoomPage(room: room)));
                        }
                      },
                      // 꾹 누르면 차단/삭제 (복원은 설정 → 친구 관리)
                      onLongPress: () => _showFriendActions(friend, l10n),
                    ),
                ]),
        );
      },
    );
  }

  /// 친구 추가 방식 선택 — iOS 액션시트 (Cupertino)
  void _showAddSheet(HanChatL10n l10n) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.t('friends.addSheetTitle')),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _sync(ContactSyncMode.all);
            },
            child: Text(l10n.t('friends.syncAll')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _sync(ContactSyncMode.manual);
            },
            child: Text(l10n.t('friends.syncManual')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.t('cancel')),
        ),
      ),
    );
  }

  Future<void> _sync(ContactSyncMode mode) async {
    final showSheet = await _vm.syncContacts(mode);
    if (showSheet && mounted) _showCandidateSheet();
  }

  void _showFriendActions(Friend friend, HanChatL10n l10n) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.person_off),
            title: Text(friend.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(l10n.t('friend.block'),
                style: const TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _vm.block(friend.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.t('friend.hide')),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _vm.hide(friend.id);
            },
          ),
        ]),
      ),
    );
  }

  void _showCandidateSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CandidateSheet(vm: _vm),
    );
  }

  void _maybeShowError(HanChatL10n l10n) {
    final key = _vm.errorKey;
    if (key == null) return;
    _vm.errorKey = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t(key))));
    });
  }
}

class _CandidateSheet extends StatelessWidget {
  final FriendsViewModel vm;
  const _CandidateSheet({required this.vm});

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.t('cancel')),
                ),
                Expanded(
                  child: Text(l10n.t('friends.select'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: vm.selectedIds.isEmpty
                      ? null
                      : () async {
                          await vm.registerSelected();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  child: Text(l10n
                      .t('friends.add')
                      .replaceFirst('%d', '${vm.selectedIds.length}')),
                ),
              ]),
            ),
            Expanded(
              child: vm.candidates.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.t('friends.noCandidates'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(l10n.t('friends.noCandidatesDesc'),
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]))
                  : ListView(children: [
                      for (final c in vm.candidates)
                        CheckboxListTile(
                          value: vm.selectedIds.contains(c.id),
                          onChanged: (_) => vm.toggleCandidate(c.id),
                          title: Text(c.localName ?? c.nickname),
                          subtitle: c.localName != null
                              ? Text(c.nickname, style: const TextStyle(fontSize: 12))
                              : null,
                          secondary: _Avatar(name: c.localName ?? c.nickname),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        child: Text(name.isEmpty ? '?' : name.characters.first,
            style: const TextStyle(color: Colors.black54)),
      );
}
