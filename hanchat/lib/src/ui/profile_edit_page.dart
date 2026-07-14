import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'l10n.dart';
import 'theme.dart';

/// 내 프로필 편집 — 프로필 사진 + 배경 사진 (최소 기능: 선택 → 자르기 → 저장).
///
/// 저장 전략(서버비 최소): 이미지는 서버에 올리지 않고 **기기 로컬**에만 둔다.
/// 저장 전 리사이즈(프로필 512px, 배경 1080px)해서 용량을 수십 KB로 줄인다.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  User? _me;

  @override
  void initState() {
    super.initState();
    HanChat.client.getCurrentUser().then((me) {
      if (mounted) setState(() => _me = me);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);
    final me = _me;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('profile.edit'))),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              // 배경 + 프로필 (겹쳐서)
              SizedBox(
                height: 220,
                child: Stack(clipBehavior: Clip.none, children: [
                  // 배경
                  GestureDetector(
                    onTap: () => _pick(isCover: true),
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      color: theme.accent.withValues(alpha: 0.25),
                      child: me.coverImagePath != null
                          ? Image.file(File(me.coverImagePath!), fit: BoxFit.cover)
                          : Center(
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  size: 36, color: theme.accent)),
                    ),
                  ),
                  // 프로필 (원형, 배경 위에 걸침)
                  Positioned(
                    left: 24,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _pick(isCover: false),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: me.profileImagePath != null
                            ? FileImage(File(me.profileImagePath!))
                            : null,
                        child: me.profileImagePath == null
                            ? Text(me.nickname.characters.first,
                                style: const TextStyle(
                                    fontSize: 32, color: Colors.black54))
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 84,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: theme.accent,
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.t('nickname')),
                trailing: Text(me.nickname),
              ),
              ListTile(
                title: Text(l10n.t('profile.status')),
                subtitle: Text(
                  me.statusMessage?.isNotEmpty == true
                      ? me.statusMessage!
                      : l10n.t('profile.statusHint'),
                  style: TextStyle(
                      color: me.statusMessage?.isNotEmpty == true
                          ? null
                          : Colors.grey.shade500),
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editStatus(me),
              ),
              if (me.profileImagePath != null || me.coverImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(l10n.t('profile.removePhotos'),
                      style: const TextStyle(color: Colors.red)),
                  onTap: _removeAll,
                ),
            ]),
    );
  }

  Future<void> _pick({required bool isCover}) async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    // 자르기 (프로필=정사각, 배경=16:9)
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: isCover
          ? const CropAspectRatio(ratioX: 16, ratioY: 9)
          : const CropAspectRatio(ratioX: 1, ratioY: 1),
    );
    if (cropped == null || !mounted) return;

    // 리사이즈 후 앱 문서 폴더에 저장 (용량 절감)
    final savedPath = await _resizeAndSave(
      cropped.path,
      maxSize: isCover ? 1080 : 512,
      name: isCover ? 'cover' : 'profile',
    );

    if (isCover) {
      await HanChat.client.updateProfileImages(
          profilePath: _me?.profileImagePath, coverPath: savedPath);
    } else {
      await HanChat.client.updateProfileImages(
          profilePath: savedPath, coverPath: _me?.coverImagePath);
    }
    await _refreshAndPublish();
  }

  Future<void> _editStatus(User me) async {
    final l10n = HanChatL10n.of(context);
    final controller = TextEditingController(text: me.statusMessage ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('profile.status')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: l10n.t('profile.statusHint')),
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
    if (result == null || !mounted) return;
    await HanChat.client.updateStatusMessage(result);
    await _refreshAndPublish();
  }

  /// 로컬 갱신 후 서버에 발행 (친구가 볼 수 있게).
  Future<void> _refreshAndPublish() async {
    final me = await HanChat.client.getCurrentUser();
    if (me != null) {
      await HanChat.client.publishProfile(
        userId: me.id,
        nickname: me.nickname,
        localProfilePath: me.profileImagePath,
        localCoverPath: me.coverImagePath,
        statusMessage: me.statusMessage,
      );
    }
    if (mounted) setState(() => _me = me);
  }

  Future<String> _resizeAndSave(String sourcePath,
      {required int maxSize, required String name}) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    final resized = decoded == null
        ? bytes
        : img.encodeJpg(
            img.copyResize(decoded,
                width: decoded.width >= decoded.height ? maxSize : null,
                height: decoded.height > decoded.width ? maxSize : null),
            quality: 85,
          );
    final dir = await getApplicationDocumentsDirectory();
    // 파일명에 타임스탬프 → 캐시 무효화
    final path = p.join(
        dir.path, '${name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(path).writeAsBytes(resized);
    return path;
  }

  Future<void> _removeAll() async {
    await HanChat.client.updateProfileImages(profilePath: null, coverPath: null);
    await _refreshAndPublish();
  }
}
