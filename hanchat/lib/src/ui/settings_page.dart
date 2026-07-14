import 'dart:io';

import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../core/support_content.dart';
import '../data/client.dart';
import '../data/read_receipt_setting.dart';
import 'admin_session.dart';
import 'drawing.dart';
import 'emoticon_shop_page.dart';
import 'friend_manage_page.dart';
import 'l10n.dart';
import 'policy_web_page.dart';
import 'profile_edit_page.dart';
import 'support_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? _me;
  bool _replayEnabled = true;
  bool _readReceiptEnabled = false;
  int _versionTaps = 0; // 앱 정보 10회 탭 → 관리자 잠금 해제

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
    ReadReceiptSetting.isEnabled().then((enabled) {
      if (mounted) setState(() => _readReceiptEnabled = enabled);
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
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            backgroundImage: _me?.profileImagePath != null
                ? FileImage(File(_me!.profileImagePath!))
                : null,
            child: _me?.profileImagePath == null
                ? Text((_me?.nickname ?? '?').characters.first,
                    style: const TextStyle(color: Colors.black54))
                : null,
          ),
          title: Text(_me?.nickname ?? ''),
          subtitle: Text(l10n.t('profile.edit'),
              style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const ProfileEditPage()));
            final me = await HanChat.client.getCurrentUser();
            if (mounted) setState(() => _me = me);
          },
        ),
        ListTile(
          title: Text(l10n.t('friend.manage')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const FriendManagePage())),
        ),
        // 이모티콘: 하단 탭에서 빠지고 여기로
        ListTile(
          leading: const Icon(Icons.emoji_emotions_outlined),
          title: Text(l10n.t('tab.emoticons')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const EmoticonShopPage())),
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
        SwitchListTile(
          title: Text(l10n.t('settings.readReceipt')),
          subtitle: Text(l10n.t('settings.readReceiptDesc'),
              style: const TextStyle(fontSize: 12)),
          value: _readReceiptEnabled,
          onChanged: (value) {
            setState(() => _readReceiptEnabled = value);
            ReadReceiptSetting.setEnabled(value);
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
        // 지원: 공지사항 · FAQ
        _sectionHeader(l10n.t('support.section')),
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: Text(l10n.t('support.announcements')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  const SupportPage(channel: SupportChannel.announcements))),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.t('support.faq')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SupportPage(channel: SupportChannel.faq))),
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
        // 앱 정보 — 10회 탭하면 관리자 잠금 해제 (숨겨진 진입점)
        ListenableBuilder(
          listenable: AdminSession.instance,
          builder: (context, _) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.t('settings.appInfo')),
            subtitle: AdminSession.instance.isAdmin
                ? Text(l10n.t('admin.active'),
                    style: const TextStyle(color: Colors.green, fontSize: 12))
                : null,
            trailing: const Text('v0.1.0', style: TextStyle(color: Colors.grey)),
            onTap: _onVersionTap,
          ),
        ),
      ]),
    );
  }

  void _onVersionTap() {
    if (AdminSession.instance.isAdmin) return;
    _versionTaps++;
    if (_versionTaps >= 10) {
      _versionTaps = 0;
      _promptAdminPassword();
    }
  }

  Future<void> _promptAdminPassword() async {
    final l10n = HanChatL10n.of(context);
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('admin.title')),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.t('admin.password')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel'))),
          TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.t('ok'))),
        ],
      ),
    );
    if (password == null || password.isEmpty || !mounted) return;

    // 비번은 서버(Cloud Function)에서 검증 — 앱엔 비번을 두지 않는다
    final token = await HanChat.client.unlockAdmin(password);
    if (!mounted) return;
    if (token != null) {
      AdminSession.instance.enter(token);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('admin.unlocked')),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('admin.wrong')),
        behavior: SnackBarBehavior.floating,
      ));
    }
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
