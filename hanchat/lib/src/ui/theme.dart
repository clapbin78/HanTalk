import 'package:flutter/material.dart';

/// 호스트 앱 브랜드에 맞게 오버라이드 가능한 테마.
class HanChatTheme {
  final Color accent;
  final Color myBubble;
  final Color otherBubble;

  const HanChatTheme({
    this.accent = const Color(0xFF2E9E5B), // 한톡 그린
    this.myBubble = const Color(0xFFC8F0D6),
    this.otherBubble = const Color(0xFFE9E9EB),
  });

  static HanChatTheme of(BuildContext context) =>
      _HanChatThemeScope.maybeOf(context) ?? const HanChatTheme();
}

class HanChatThemeScope extends StatelessWidget {
  final HanChatTheme theme;
  final Widget child;

  const HanChatThemeScope({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) =>
      _HanChatThemeScope(theme: theme, child: child);
}

class _HanChatThemeScope extends InheritedWidget {
  final HanChatTheme theme;

  const _HanChatThemeScope({required this.theme, required super.child});

  static HanChatTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_HanChatThemeScope>()?.theme;

  @override
  bool updateShouldNotify(_HanChatThemeScope oldWidget) => theme != oldWidget.theme;
}

/// "#RRGGBB" ↔ Color (그림 벡터 포맷용)
Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceAll('#', ''), radix: 16) ?? 0;
  return Color(0xFF000000 | value);
}
