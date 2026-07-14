import 'package:flutter/material.dart';

import '../core/support_content.dart';
import '../data/client.dart';
import 'admin_session.dart';
import 'l10n.dart';

/// 공지사항 / FAQ 목록. 관리자 모드일 때만 글쓰기 버튼 노출.
class SupportPage extends StatefulWidget {
  final SupportChannel channel;
  const SupportPage({super.key, required this.channel});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<SupportPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AdminSession.instance.addListener(_onAdminChanged);
  }

  @override
  void dispose() {
    AdminSession.instance.removeListener(_onAdminChanged);
    super.dispose();
  }

  void _onAdminChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final posts = await HanChat.client.getSupportContent.fetch(widget.channel);
    if (mounted) {
      setState(() {
        _posts = posts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final title = widget.channel == SupportChannel.announcements
        ? l10n.t('support.announcements')
        : l10n.t('support.faq');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: AdminSession.instance.isAdmin
          ? FloatingActionButton(
              onPressed: _writePost,
              child: const Icon(Icons.edit),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Text(l10n.t('support.empty'),
                      style: TextStyle(color: Colors.grey.shade600)))
              : ListView(children: [
                  for (final post in _posts)
                    ExpansionTile(
                      title: Text(post.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${post.createdAt.year}.${post.createdAt.month}.${post.createdAt.day}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(post.body)],
                    ),
                ]),
    );
  }

  Future<void> _writePost() async {
    final result = await Navigator.of(context).push<SupportPost>(
      MaterialPageRoute(builder: (_) => const _WritePostPage()),
    );
    if (result == null) return;
    final token = AdminSession.instance.token;
    if (token == null) return;
    await HanChat.client.postSupport(widget.channel, result, adminToken: token);
    await _load();
  }
}

/// 관리자 글쓰기 화면.
class _WritePostPage extends StatefulWidget {
  const _WritePostPage();

  @override
  State<_WritePostPage> createState() => _WritePostPageState();
}

class _WritePostPageState extends State<_WritePostPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('support.write')),
        actions: [
          TextButton(
            onPressed: _title.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(SupportPost(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: _title.text.trim(),
                      body: _body.text.trim(),
                      createdAt: DateTime.now(),
                    )),
            child: Text(l10n.t('support.publish')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.t('support.postTitle'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _body,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                labelText: l10n.t('support.postBody'),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
