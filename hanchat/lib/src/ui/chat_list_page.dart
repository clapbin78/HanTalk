import 'dart:async';

import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'chat_room_page.dart';
import 'l10n.dart';
import 'translatable_text.dart';

class ChatListViewModel extends ChangeNotifier {
  final HanChatClient _client;
  StreamSubscription<List<ChatRoom>>? _subscription;

  List<ChatRoom> rooms = [];
  List<Friend> friends = [];
  String? myId;

  ChatListViewModel(this._client);

  void start() {
    _subscription ??= _client.observeRooms().listen((value) {
      rooms = value;
      notifyListeners();
    });
    _client.getCurrentUser().then((me) => myId = me?.id);
    _client.getFriends().then((value) {
      friends = value;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String titleFor(ChatRoom room, HanChatL10n l10n) {
    if (room.kind == RoomKind.group) return room.name ?? l10n.t('chats.group');
    final otherId = room.memberIds.where((id) => id != myId).firstOrNull;
    for (final f in friends) {
      if (f.id == otherId) return f.displayName;
    }
    return l10n.t('unknown');
  }

  Future<ChatRoom?> createGroup(String name, List<String> memberIds) async {
    final me = await _client.getCurrentUser();
    if (me == null) return null;
    return _client.createRoom.group(name: name, memberIds: [me.id, ...memberIds]);
  }
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late final _vm = ChatListViewModel(HanChat.client)..start();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('tab.chats')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: () => _showNewGroupSheet(context),
            ),
          ],
        ),
        body: _vm.rooms.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.t('chats.empty'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(l10n.t('chats.emptyDesc'),
                    style: TextStyle(color: Colors.grey.shade600)),
              ]))
            : ListView(children: [
                for (final room in _vm.rooms)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(_vm.titleFor(room, l10n).characters.first,
                          style: const TextStyle(color: Colors.black54)),
                    ),
                    title: Row(children: [
                      Flexible(child: TranslatableText(_vm.titleFor(room, l10n))),
                      if (room.kind == RoomKind.group) ...[
                        const SizedBox(width: 6),
                        Text('${room.memberIds.length}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ]),
                    subtitle: Text(
                      room.lastMessagePreview ?? l10n.t('chats.start'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: room.lastMessageAt == null
                        ? null
                        : Text(
                            TimeOfDay.fromDateTime(room.lastMessageAt!)
                                .format(context),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ChatRoomPage(room: room))),
                  ),
              ]),
      ),
    );
  }

  void _showNewGroupSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NewGroupSheet(vm: _vm),
    );
  }
}

class _NewGroupSheet extends StatefulWidget {
  final ChatListViewModel vm;
  const _NewGroupSheet({required this.vm});

  @override
  State<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends State<_NewGroupSheet> {
  final _name = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.t('cancel'))),
                Expanded(
                  child: Text(l10n.t('chats.newGroup'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _name.text.isEmpty || _selected.length < 2
                      ? null
                      : () async {
                          final room = await widget.vm
                              .createGroup(_name.text, _selected.toList());
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            if (room != null) {
                              Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => ChatRoomPage(room: room)));
                            }
                          }
                        },
                  child: Text(l10n.t('chats.create')),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.t('chats.roomName'),
                  hintText: l10n.t('chats.roomNameHint'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.t('chats.invite'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
            ),
            Expanded(
              child: ListView(children: [
                for (final friend in widget.vm.friends)
                  CheckboxListTile(
                    value: _selected.contains(friend.id),
                    onChanged: (_) => setState(() {
                      _selected.contains(friend.id)
                          ? _selected.remove(friend.id)
                          : _selected.add(friend.id);
                    }),
                    title: Text(friend.displayName),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
