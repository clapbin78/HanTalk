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
    const coverHeight = 150.0;
    const avatarRadius = 44.0;

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final profile = _vm.profile;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          extendBodyBehindAppBar: true,
          body: ListView(padding: EdgeInsets.zero, children: [
            // 배경 + 아바타 (아바타가 배경 아래로 살짝 걸침)
            SizedBox(
              height: coverHeight + avatarRadius,
              child: Stack(clipBehavior: Clip.none, children: [
                SizedBox(
                  height: coverHeight,
                  width: double.infinity,
                  child: _cover(profile),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircleAvatar(
                      radius: avatarRadius + 4,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            _imageProvider(profile?.profileImageUrl),
                        child: _imageProvider(profile?.profileImageUrl) == null
                            ? Text(_vm.displayName.characters.first,
                                style: const TextStyle(
                                    fontSize: 30, color: Colors.black54))
                            : null,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(_vm.displayName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            if (profile?.statusMessage case final status?
                when status.isNotEmpty) ...[
              const SizedBox(height: 6),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(status,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              ),
            ],
            if (_vm.loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
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
