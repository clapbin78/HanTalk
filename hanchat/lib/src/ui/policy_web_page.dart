import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 약관·개인정보처리방침 인앱 웹뷰.
/// iOS는 WKWebView, Android는 WebView — 주소창 없이 콘텐츠만 표시.
class PolicyWebPage extends StatefulWidget {
  final String title;
  final Uri url;

  const PolicyWebPage({super.key, required this.title, required this.url});

  @override
  State<PolicyWebPage> createState() => _PolicyWebPageState();
}

class _PolicyWebPageState extends State<PolicyWebPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled) // 정적 문서라 JS 불필요
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
