import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'l10n.dart';

/// 차단·삭제한 친구 관리 — 복원 가능.
class FriendManagePage extends StatefulWidget {
  const FriendManagePage({super.key});

  @override
  State<FriendManagePage> createState() => _FriendManagePageState();
}

class _FriendManagePageState extends State<FriendManagePage> {
  List<Friend> _managed = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final managed = await HanChat.client.manageFriends.managed();
    if (mounted) setState(() => _managed = managed);
  }

  Future<void> _restore(Friend friend) async {
    await HanChat.client.manageFriends.restore(friend.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final blocked = [
      for (final f in _managed) if (f.status == FriendStatus.blocked) f,
    ];
    final hidden = [
      for (final f in _managed) if (f.status == FriendStatus.hidden) f,
    ];

    Widget section(String title, List<Friend> friends) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
            ),
            for (final friend in friends)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade300,
                  child: Text(friend.displayName.characters.first,
                      style: const TextStyle(color: Colors.black54)),
                ),
                title: Text(friend.displayName),
                trailing: OutlinedButton(
                  onPressed: () => _restore(friend),
                  child: Text(l10n.t('friend.restore')),
                ),
              ),
          ],
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('friend.manage'))),
      body: _managed.isEmpty
          ? Center(
              child: Text(l10n.t('friend.manageEmpty'),
                  style: TextStyle(color: Colors.grey.shade600)))
          : ListView(children: [
              if (blocked.isNotEmpty) section(l10n.t('friend.blockedSection'), blocked),
              if (hidden.isNotEmpty) section(l10n.t('friend.hiddenSection'), hidden),
            ]),
    );
  }
}
