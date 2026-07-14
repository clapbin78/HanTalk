import 'package:flutter/material.dart';

import '../core/report.dart';
import '../data/client.dart';
import 'admin_session.dart';
import 'l10n.dart';

/// 관리자 콘솔 — 신고 목록 + 정지 관리. 관리자 모드에서만 진입.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('admin.console')),
          bottom: TabBar(tabs: [
            Tab(text: l10n.t('admin.reports')),
            Tab(text: l10n.t('admin.suspensions')),
          ]),
        ),
        body: const TabBarView(children: [_ReportsTab(), _SuspensionsTab()]),
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Report> _reports = [];
  bool _loading = true;

  String get _token => AdminSession.instance.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await HanChat.client.adminModeration.reports(_token);
    if (mounted) {
      setState(() {
        _reports = reports;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reports.isEmpty) {
      return Center(
          child: Text(l10n.t('admin.noReports'),
              style: TextStyle(color: Colors.grey.shade600)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        for (final r in _reports)
          ListTile(
            leading: const Icon(Icons.flag, color: Colors.orange),
            title: Text('${l10n.t('report.${r.reason.name}')} · ${r.targetType.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.t('admin.reported')}: ${r.reportedUserId}',
                    style: const TextStyle(fontSize: 12)),
                if (r.snapshot != null)
                  Text('"${r.snapshot}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: TextButton(
              onPressed: () => _suspend(r.reportedUserId, r),
              child: Text(l10n.t('admin.suspend'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
      ]),
    );
  }

  Future<void> _suspend(String userId, Report report) async {
    final l10n = HanChatL10n.of(context);
    final controller = TextEditingController(
        text: '${l10n.t('report.${report.reason.name}')} 신고');
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('admin.suspendTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.t('admin.suspendReason')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel'))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.t('admin.suspend'))),
        ],
      ),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    try {
      await HanChat.client.adminModeration
          .suspend(userId: userId, reason: reason, adminToken: _token);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('admin.suspended')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
  }
}

class _SuspensionsTab extends StatefulWidget {
  const _SuspensionsTab();
  @override
  State<_SuspensionsTab> createState() => _SuspensionsTabState();
}

class _SuspensionsTabState extends State<_SuspensionsTab> {
  List<Suspension> _list = [];
  bool _loading = true;

  String get _token => AdminSession.instance.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await HanChat.client.adminModeration.suspensions(_token);
    if (mounted) {
      setState(() {
        _list = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_list.isEmpty) {
      return Center(
          child: Text(l10n.t('admin.noSuspensions'),
              style: TextStyle(color: Colors.grey.shade600)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        for (final s in _list)
          ListTile(
            leading: const Icon(Icons.person_off, color: Colors.red),
            title: Text(s.userId),
            // 정지 사유 메모가 남아 나중에 확인 가능
            subtitle: Text('${s.reason}\n${_date(s.suspendedAt)}',
                style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: () async {
                await HanChat.client.adminModeration
                    .unsuspend(userId: s.userId, adminToken: _token);
                await _load();
              },
              child: Text(l10n.t('admin.unsuspend')),
            ),
          ),
      ]),
    );
  }

  String _date(DateTime d) =>
      '${d.year}.${d.month}.${d.day} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
