import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'drawing.dart';
import 'friend_manage_page.dart';
import 'l10n.dart';
import 'policy_web_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _me;
  bool _replayEnabled = true;

  HanChatConfig get _config => HanChat.client.config;

  @override
  void initState() {
    super.initState();
    HanChat.client.getCurrentUser().then((me) {
      if (mounted) setState(() => _me = me);
    });
    DrawingReplaySetting.isEnabled().then((enabled) {
      if (mounted) setState(() => _replayEnabled = enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final retention = _config.localRetention.expireAfter;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('tab.settings'))),
      body: ListView(children: [
        _sectionHeader(l10n.t('friends.my')),
        ListTile(
          title: Text(l10n.t('nickname')),
          trailing: Text(_me?.nickname ?? ''),
        ),
        ListTile(
          title: Text(l10n.t('friend.manage')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const FriendManagePage())),
        ),
        _sectionHeader(l10n.t('settings.chat')),
        SwitchListTile(
          title: Text(l10n.t('settings.replay')),
          subtitle: Text(l10n.t('settings.replayDesc'),
              style: const TextStyle(fontSize: 12)),
          value: _replayEnabled,
          onChanged: (value) {
            setState(() => _replayEnabled = value);
            DrawingReplaySetting.setEnabled(value);
          },
        ),
        _sectionHeader(l10n.t('settings.retention')),
        ListTile(
          title: Text(l10n.t('settings.autoDelete')),
          trailing: Text(retention == null
              ? l10n.t('settings.never')
              : l10n
                  .t('settings.afterHours')
                  .replaceFirst('%d', '${retention.inHours}')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.t('settings.retentionDesc'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        // 약관 URL이 주입된 경우에만 표시 (호스트 앱이 자체 약관을 쓰면 안 보임)
        if (_config.hasPolicies) ...[
          _sectionHeader(l10n.t('settings.policies')),
          ListTile(
            title: Text(l10n.t('terms')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PolicyWebPage(
                    title: l10n.t('terms'), url: _config.termsOfServiceUrl!))),
          ),
          ListTile(
            title: Text(l10n.t('privacy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PolicyWebPage(
                    title: l10n.t('privacy'), url: _config.privacyPolicyUrl!))),
          ),
        ],
      ]),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600)),
      );
}
