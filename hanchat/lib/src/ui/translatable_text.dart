import 'package:flutter/material.dart';

import '../core/usecases.dart';
import '../data/client.dart';
import 'l10n.dart';
import 'mlkit_translator.dart';

/// 어디든 붙이는 인라인 번역 텍스트.
///
/// 꾹 누르면 "번역" 메뉴 → **그 자리에서 번역본으로 교체** (바텀시트 없음).
/// 다시 꾹 누르면 "원문 보기". 메시지·닉네임·방 이름 어디에나 사용.
///
/// 번역 엔진: 커스텀 TranslationService 주입 시 UseCase 경유 (Phase 4: AI),
/// 없으면 ML Kit 온디바이스 (무료, iOS/Android 공통).
/// 꾹 누르기 메뉴에 추가할 항목 (복사·전달·공유 등 — 호출부가 주입).
class TextMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const TextMenuAction({required this.icon, required this.label, required this.onTap});
}

class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// 번역/원문 아래에 붙는 추가 메뉴 (메시지 말풍선: 복사·전달·공유)
  final List<TextMenuAction> extraActions;

  const TranslatableText(
    this.text, {
    super.key,
    this.style,
    this.extraActions = const [],
  });

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  String? _translated;
  bool _translating = false;

  TranslateTextUseCase? get _customTranslate => HanChat.client.translateText;

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return GestureDetector(
      onLongPressStart: (details) => _showMenu(context, details.globalPosition, l10n),
      child: Opacity(
        opacity: _translating ? 0.4 : 1,
        child: _translated == null
            ? Text(widget.text, style: widget.style)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_translated!, style: widget.style),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.g_translate, size: 11, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(l10n.t('translate.badge'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                ],
              ),
      ),
    );
  }

  Future<void> _showMenu(
      BuildContext context, Offset position, HanChatL10n l10n) async {
    final action = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      items: [
        if (_translated == null)
          PopupMenuItem<Object>(
            value: 'translate',
            child: Row(children: [
              const Icon(Icons.g_translate, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('translate')),
            ]),
          )
        else
          PopupMenuItem<Object>(
            value: 'original',
            child: Row(children: [
              const Icon(Icons.undo, size: 18),
              const SizedBox(width: 8),
              Text(l10n.t('translate.original')),
            ]),
          ),
        for (final extra in widget.extraActions)
          PopupMenuItem<Object>(
            value: extra,
            child: Row(children: [
              Icon(extra.icon, size: 18),
              const SizedBox(width: 8),
              Text(extra.label),
            ]),
          ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'translate':
        await _translate(l10n);
      case 'original':
        setState(() => _translated = null);
      case final TextMenuAction extra:
        extra.onTap();
      default:
    }
  }

  Future<void> _translate(HanChatL10n l10n) async {
    setState(() => _translating = true);
    final target = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    String? result;
    final custom = _customTranslate;
    if (custom != null) {
      // 1순위: 주입된 번역 서비스 (UseCase 경유 — MVVM 규칙 유지)
      try {
        result = await custom(widget.text, toLanguage: target);
      } catch (_) {}
    } else {
      // 2순위: ML Kit 온디바이스
      result = await MLKitTranslator.instance.translate(
        widget.text,
        toLanguageCode: target,
      );
    }

    if (!mounted) return;
    setState(() {
      _translating = false;
      _translated = result;
    });
    if (result == null && mounted) {
      // floating: 입력창을 가리지 않게 띄움
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l10n.t('translate.failed')),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
