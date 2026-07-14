import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'theme.dart';

/// 오프라인일 때 화면 상단에 뜨는 얇은 배너. 앱 전체를 감싼다.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted && offline != _offline) setState(() => _offline = offline);
    });
    // 초기 상태 확인
    Connectivity().checkConnectivity().then((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _offline = offline);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    return Column(children: [
      widget.child.expandInColumn(),
      // 애니메이션으로 부드럽게 등장
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _offline ? 26 : 0,
        color: Colors.redAccent,
        alignment: Alignment.center,
        child: _offline
            ? Text(l10n.t('net.offline'),
                style: const TextStyle(color: Colors.white, fontSize: 12))
            : null,
      ),
    ]);
  }
}

extension on Widget {
  Widget expandInColumn() => Expanded(child: this);
}

/// 로드 실패(네트워크 등) 시 보여주는 재시도 화면. 목록·상세 어디서든 재사용.
class NetworkErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const NetworkErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(l10n.t('net.errorTitle'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(l10n.t('net.errorDesc'),
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('net.retry')),
          style: OutlinedButton.styleFrom(foregroundColor: theme.accent),
        ),
      ]),
    );
  }
}
