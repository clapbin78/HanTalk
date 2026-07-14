import 'dart:io';

import 'package:flutter/material.dart';

import '../core/profile.dart';
import '../data/client.dart';
import 'theme.dart';

/// 상대 프로필 보기 — 이름/아이콘을 누르면 열린다. 사진 + 배경 표시.
class ProfileViewViewModel extends ChangeNotifier {
  final HanChatClient _client;
  final String userId;
  final String fallbackName;

  PublicProfile? profile;
  bool loading = true;

  ProfileViewViewModel(this._client,
      {required this.userId, required this.fallbackName});

  Future<void> load() async {
    profile = await _client.getProfile(userId);
    loading = false;
    notifyListeners();
  }

  String get displayName => profile?.nickname ?? fallbackName;
}

class ProfileViewPage extends StatefulWidget {
  final String userId;
  final String fallbackName;
  const ProfileViewPage(
      {super.key, required this.userId, required this.fallbackName});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  late final _vm = ProfileViewViewModel(HanChat.client,
      userId: widget.userId, fallbackName: widget.fallbackName)
    ..load();

  @override
  Widget build(BuildContext context) {
    final theme = HanChatTheme.of(context);

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final profile = _vm.profile;
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: theme.accent,
              flexibleSpace: FlexibleSpaceBar(
                background: _cover(profile),
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -44),
                child: Column(children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _imageProvider(profile?.profileImageUrl),
                      child: _imageProvider(profile?.profileImageUrl) == null
                          ? Text(_vm.displayName.characters.first,
                              style: const TextStyle(
                                  fontSize: 30, color: Colors.black54))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_vm.displayName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  if (_vm.loading) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _cover(PublicProfile? profile) {
    final provider = _imageProvider(profile?.coverImageUrl);
    if (provider == null) {
      return Container(color: HanChatTheme.of(context).accent.withValues(alpha: 0.3));
    }
    return Image(image: provider, fit: BoxFit.cover);
  }

  /// 로컬 파일 경로(데모)와 http URL(실서비스) 모두 지원.
  ImageProvider? _imageProvider(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http')) return NetworkImage(pathOrUrl);
    return FileImage(File(pathOrUrl));
  }
}

/// 이름/아이콘 탭 → 프로필 열기 (재사용 헬퍼).
void openProfile(BuildContext context,
    {required String userId, required String fallbackName}) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) =>
        ProfileViewPage(userId: userId, fallbackName: fallbackName),
  ));
}
