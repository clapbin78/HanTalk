import 'package:flutter/material.dart';

import '../data/client.dart';
import 'chat_list_page.dart';
import 'friends_page.dart';
import 'l10n.dart';
import 'onboarding_page.dart';
import 'settings_page.dart';
import 'theme.dart';

/// SDK가 제공하는 최상위 화면. 호스트 앱은 HanChat.configure() 후 이 위젯만 띄우면 된다.
class HanChatRootView extends StatefulWidget {
  final HanChatTheme theme;
  const HanChatRootView({super.key, this.theme = const HanChatTheme()});

  @override
  State<HanChatRootView> createState() => _HanChatRootViewState();
}

class _HanChatRootViewState extends State<HanChatRootView>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 포그라운드 진입 시: 수신 재개 + 24시간 지난 메시지 정리
    if (state == AppLifecycleState.resumed) {
      HanChat.client.start();
    }
  }

  Future<void> _check() async {
    final me = await HanChat.client.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _registered = me != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HanChatThemeScope(
      theme: widget.theme,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _registered
              ? const _MainTabs()
              : OnboardingPage(onComplete: () => setState(() => _registered = true)),
    );
  }
}

class _MainTabs extends StatefulWidget {
  const _MainTabs();

  @override
  State<_MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<_MainTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    // 하단바는 친구·채팅 2개. 설정은 각 탭 앱바 우상단 아이콘으로.
    // 이모티콘은 탭에서 빠지고 설정 화면 안으로 들어감.
    return Scaffold(
      body: IndexedStack(index: _index, children: const [
        FriendsPage(),
        ChatListPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.people), label: l10n.t('tab.friends')),
          NavigationDestination(
              icon: const Icon(Icons.chat_bubble), label: l10n.t('tab.chats')),
        ],
      ),
    );
  }
}

/// 각 탭 앱바 우상단에 넣는 설정 진입 버튼.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings),
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
    );
  }
}
