import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../core/support_content.dart';
import '../data/client.dart';
import '../data/notification_setting.dart';
import '../data/read_receipt_setting.dart';
import '../data/retention_setting.dart';
import 'admin_page.dart';
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
  bool _notifEnabled = true;
  bool _vibrateEnabled = true;
  bool _soundEnabled = true;
  String _retentionOption = RetentionSetting.optionOff;
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
    NotificationSetting.notificationsEnabled().then((v) {
      if (mounted) setState(() => _notifEnabled = v);
    });
    NotificationSetting.vibrateEnabled().then((v) {
      if (mounted) setState(() => _vibrateEnabled = v);
    });
    NotificationSetting.soundEnabled().then((v) {
      if (mounted) setState(() => _soundEnabled = v);
    });
    RetentionSetting.currentOption(_config.localRetention).then((opt) {
      if (mounted) setState(() => _retentionOption = opt);
    });
  }

  String _retentionKey(String opt) => switch (opt) {
        RetentionSetting.option24h => 'retention.h24',
        RetentionSetting.option7d => 'retention.d7',
        _ => 'retention.off',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

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
        // 알림 — 실제 푸시 발송은 서버(Firebase FCM) 연동 시 이 값을 참조
        _sectionHeader(l10n.t('settings.notif')),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_none),
          title: Text(l10n.t('settings.notifAll')),
          value: _notifEnabled,
          onChanged: (value) {
            setState(() => _notifEnabled = value);
            NotificationSetting.setNotificationsEnabled(value);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.vibration),
          title: Text(l10n.t('settings.vibrate')),
          value: _vibrateEnabled,
          // 알림이 꺼져 있으면 하위 설정 비활성
          onChanged: _notifEnabled
              ? (value) {
                  setState(() => _vibrateEnabled = value);
                  NotificationSetting.setVibrateEnabled(value);
                }
              : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: Text(l10n.t('settings.sound')),
          value: _soundEnabled,
          onChanged: _notifEnabled
              ? (value) {
                  setState(() => _soundEnabled = value);
                  NotificationSetting.setSoundEnabled(value);
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.t('settings.notifNote'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        _sectionHeader(l10n.t('settings.retention')),
        // 사라지는 메시지 — 기본은 계속 보관, 24시간/7일 선택 가능
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.t('settings.disappearing')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.t(_retentionKey(_retentionOption)),
                style: TextStyle(color: Colors.grey.shade600)),
            const Icon(Icons.chevron_right),
          ]),
          onTap: () => _pickRetention(l10n),
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
        // 관리자 콘솔 — 관리자 모드일 때만 노출
        ListenableBuilder(
          listenable: AdminSession.instance,
          builder: (context, _) => AdminSession.instance.isAdmin
              ? ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.green),
                  title: Text(l10n.t('admin.openConsole')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AdminPage())),
                )
              : const SizedBox.shrink(),
        ),
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

  void _pickRetention(HanChatL10n l10n) {
    void choose(String opt) {
      Navigator.of(context).pop();
      setState(() => _retentionOption = opt);
      RetentionSetting.setOption(opt).then((_) {
        // 더 짧은 기간으로 바꾸면 지난 메시지도 즉시 정리
        HanChat.client.purgeExpired();
      });
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.t('settings.disappearing')),
        message: Text(l10n.t('settings.disappearingDesc')),
        actions: [
          for (final opt in const [
            RetentionSetting.optionOff,
            RetentionSetting.option24h,
            RetentionSetting.option7d,
          ])
            CupertinoActionSheetAction(
              onPressed: () => choose(opt),
              child: Text(l10n.t(_retentionKey(opt))),
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
