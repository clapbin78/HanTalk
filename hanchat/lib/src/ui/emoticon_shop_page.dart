import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'drawing.dart';
import 'l10n.dart';
import 'theme.dart';

class EmoticonShopViewModel extends ChangeNotifier {
  final HanChatClient _client;

  List<Emoticon> gallery = [];
  Set<String> ownedIds = {};
  bool loading = false;
  String? errorKey;

  /// 임티샵 옵션(업로드/판매) — 서버가 appId 결제 확인을 해줘야만 true.
  /// 클라이언트에서 뭘 켜도 서버 확인 없이는 업로드 UI가 노출되지 않는다.
  bool uploadAllowed = false;

  EmoticonShopViewModel(this._client);

  /// 🚩 유료 기능 노출 여부 — Phase 3에서 config로 켠다
  bool get paidEnabled => _client.config.paidEmoticonsEnabled;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      gallery = await _client.browseEmoticons();
      ownedIds = {for (final e in await _client.getMyEmoticons()) e.id};
      uploadAllowed = (await _client.getShopEntitlement()).uploadEnabled;
    } catch (e) {
      errorKey = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> acquire(Emoticon emoticon) async {
    try {
      await _client.acquireEmoticon(emoticon);
      ownedIds.add(emoticon.id);
      notifyListeners();
    } catch (e) {
      errorKey = e.toString();
      notifyListeners();
    }
  }

  Future<bool> upload(String name, DrawingPayload payload, int price) async {
    try {
      await _client.uploadEmoticon(name: name, payload: payload, price: price);
      await load();
      return true;
    } catch (e) {
      errorKey = e.toString();
      notifyListeners();
      return false;
    }
  }
}

/// 이모티콘 갤러리 (지금은 전부 무료 공개 — 유료 UI는 플래그 뒤에 준비됨)
class EmoticonShopPage extends StatefulWidget {
  const EmoticonShopPage({super.key});

  @override
  State<EmoticonShopPage> createState() => _EmoticonShopPageState();
}

class _EmoticonShopPageState extends State<EmoticonShopPage> {
  late final _vm = EmoticonShopViewModel(HanChat.client)..load();

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        _maybeShowError(l10n);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('tab.emoticons')),
            actions: [
              // 업로드 = 유료 옵션. 서버 결제 확인(entitlement) 없으면 버튼 자체가 없음.
              if (_vm.uploadAllowed)
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _startUploadFlow,
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _vm.load,
            child: _vm.gallery.isEmpty && !_vm.loading
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                        child: Column(children: [
                      Text(l10n.t('emo.empty'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(l10n.t('emo.emptyDesc'),
                          style: TextStyle(color: Colors.grey.shade600)),
                    ])),
                  ])
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: _vm.gallery.length,
                    itemBuilder: (context, index) => _EmoticonCard(
                      emoticon: _vm.gallery[index],
                      owned: _vm.ownedIds.contains(_vm.gallery[index].id),
                      paidEnabled: _vm.paidEnabled,
                      onAcquire: () => _vm.acquire(_vm.gallery[index]),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _startUploadFlow() async {
    final payload = await Navigator.of(context).push<DrawingPayload>(
      MaterialPageRoute(
        builder: (_) => const DrawingCanvasPage(confirmLabelKey: 'next'),
        fullscreenDialog: true,
      ),
    );
    if (payload == null || !mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UploadSheet(vm: _vm, payload: payload),
    );
  }

  void _maybeShowError(HanChatL10n l10n) {
    final key = _vm.errorKey;
    if (key == null) return;
    _vm.errorKey = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.error(key))));
    });
  }
}

class _EmoticonCard extends StatelessWidget {
  final Emoticon emoticon;
  final bool owned;
  final bool paidEnabled;
  final VoidCallback onAcquire;

  const _EmoticonCard({
    required this.emoticon,
    required this.owned,
    required this.paidEnabled,
    required this.onAcquire,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);

    // 🚩 유료 가격표 — paidEnabled가 켜지기 전엔 전부 무료라 '받기'만 보임
    final buttonLabel = owned
        ? l10n.t('emo.owned')
        : (paidEnabled && !emoticon.isFree)
            ? l10n.t('emo.price').replaceFirst('%d', '${emoticon.price}')
            : l10n.t('emo.get');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Expanded(child: DrawingThumbnail(emoticon.payload)),
        const SizedBox(height: 6),
        Text(emoticon.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(emoticon.creatorNickname,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.black87,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: owned ? null : onAcquire,
            child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

class _UploadSheet extends StatefulWidget {
  final EmoticonShopViewModel vm;
  final DrawingPayload payload;
  const _UploadSheet({required this.vm, required this.payload});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.t('emo.uploadTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(height: 120, child: DrawingThumbnail(widget.payload)),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.t('emo.name'),
              hintText: l10n.t('emo.nameHint'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          // 🚩 유료 가격 입력 — Phase 3에서 paidEmoticonsEnabled로 노출
          if (widget.vm.paidEnabled) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.t('emo.priceSection'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(l10n.t('emo.disclosure'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _name.text.isEmpty || _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.t('emo.upload')),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _upload() async {
    setState(() => _uploading = true);
    final price = widget.vm.paidEnabled ? (int.tryParse(_price.text) ?? 0) : 0;
    final ok = await widget.vm.upload(_name.text, widget.payload, price);
    if (mounted) {
      setState(() => _uploading = false);
      if (ok) Navigator.of(context).pop();
    }
  }
}
