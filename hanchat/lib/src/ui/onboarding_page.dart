import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/client.dart';
import 'l10n.dart';
import 'policy_web_page.dart';
import 'theme.dart';

/// 최초 설치 플로우: 접근권한 안내(한국 정보통신망법, 전 지역 공통) →
/// (약관 동의 — URL 주입 시) → 프로필 등록 → 알림 권한.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _Step { permissionNotice, consent, profile, notifications }

class _OnboardingPageState extends State<OnboardingPage> {
  // 접근권한 안내 화면은 한국(정보통신망법)에서만 의무 → 한국어 기기에서만 노출.
  // 그 외 국가는 OS의 just-in-time 권한 팝업으로 충족(별도 화면 요구 없음).
  late _Step _step = _isKorea ? _Step.permissionNotice : _firstAfterNotice;

  bool get _isKorea {
    final locale = PlatformDispatcher.instance.locale;
    return locale.languageCode == 'ko' || locale.countryCode == 'KR';
  }

  _Step get _firstAfterNotice =>
      _config.hasPolicies ? _Step.consent : _Step.profile;

  HanChatConfig get _config => HanChat.client.config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          _Step.permissionNotice => _PermissionNoticeStep(onNext: () {
              setState(() => _step = _firstAfterNotice);
            }),
          _Step.consent => _ConsentStep(
              config: _config,
              onNext: () => setState(() => _step = _Step.profile),
            ),
          _Step.profile => _ProfileStep(
              onNext: () => setState(() => _step = _Step.notifications),
            ),
          _Step.notifications => _NotificationStep(onFinish: widget.onComplete),
        },
      ),
    );
  }
}

// ── 0. 접근 권한 안내 ─────────────────────────────────────

class _PermissionNoticeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _PermissionNoticeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);

    Widget row(IconData icon, String title, String desc) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: theme.accent, size: 28),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        Icon(Icons.verified_user, size: 56, color: theme.accent),
        const SizedBox(height: 12),
        Text(l10n.t('perm.title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(l10n.t('perm.subtitle'),
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 28),
        row(Icons.notifications, l10n.t('perm.notif'), l10n.t('perm.notifDesc')),
        const SizedBox(height: 12),
        row(Icons.contacts, l10n.t('perm.contacts'), l10n.t('perm.contactsDesc')),
        const SizedBox(height: 20),
        Text(l10n.t('perm.footer'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        _PrimaryButton(label: l10n.t('ok'), onPressed: onNext),
      ]),
    );
  }
}

// ── 1. 약관 동의 ──────────────────────────────────────────

class _ConsentStep extends StatefulWidget {
  final HanChatConfig config;
  final VoidCallback onNext;
  const _ConsentStep({required this.config, required this.onNext});

  @override
  State<_ConsentStep> createState() => _ConsentStepState();
}

class _ConsentStepState extends State<_ConsentStep> {
  bool _terms = false;
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    Widget consentRow(bool value, String title, Uri? url, ValueChanged<bool> onChanged) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: CheckboxListTile(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                title: Text(title, style: const TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            if (url != null)
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PolicyWebPage(title: title, url: url))),
                child: Text(l10n.t('onboard.view')),
              ),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        const Text('💬', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(
          l10n.t('onboard.welcome').replaceFirst('%@', widget.config.serviceName),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(l10n.t('onboard.subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        consentRow(_terms, l10n.t('onboard.agreeTerms'),
            widget.config.termsOfServiceUrl, (v) => setState(() => _terms = v)),
        const SizedBox(height: 10),
        consentRow(_privacy, l10n.t('onboard.agreePrivacy'),
            widget.config.privacyPolicyUrl, (v) => setState(() => _privacy = v)),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: l10n.t('onboard.start'),
          onPressed: _terms && _privacy ? widget.onNext : null,
        ),
      ]),
    );
  }
}

// ── 2. 프로필 등록 ────────────────────────────────────────

class _ProfileStep extends StatefulWidget {
  final VoidCallback onNext;
  const _ProfileStep({required this.onNext});

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  final _nickname = TextEditingController();
  final _phone = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 24),
        Text(l10n.t('profile.create'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(
          controller: _nickname,
          decoration: InputDecoration(
            labelText: l10n.t('nickname'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l10n.t('phone.placeholder'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(l10n.t('phone.privacy'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const Spacer(),
        _PrimaryButton(
          label: l10n.t('register'),
          loading: _submitting,
          onPressed: _nickname.text.isEmpty || _phone.text.length < 10
              ? null
              : () => _submit(l10n),
        ),
      ]),
    );
  }

  Future<void> _submit(HanChatL10n l10n) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await HanChat.client
          .registerUser(nickname: _nickname.text, phoneNumber: _phone.text);
      await HanChat.client.start();
      if (mounted) widget.onNext();
    } catch (e) {
      setState(() => _error = l10n.error(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── 3. 알림 권한 ──────────────────────────────────────────

class _NotificationStep extends StatelessWidget {
  final VoidCallback onFinish;
  const _NotificationStep({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        Icon(Icons.notifications_active, size: 56, color: theme.accent),
        const SizedBox(height: 12),
        Text(l10n.t('notif.title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.t('notif.subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        _PrimaryButton(
          label: l10n.t('notif.enable'),
          onPressed: () async {
            await Permission.notification.request();
            onFinish();
          },
        ),
        TextButton(onPressed: onFinish, child: Text(l10n.t('notif.later'))),
      ]),
    );
  }
}

// ── 공용 버튼 ─────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = HanChatTheme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.accent,
          foregroundColor: Colors.black87,
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
