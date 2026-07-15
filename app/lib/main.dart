import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hanchat/hanchat.dart';
// Firebase 모드 전환 시:
// import 'package:firebase_core/firebase_core.dart';
// import 'package:hanchat_firebase/hanchat_firebase.dart';

/// 껍데기 앱 — SDK 사용법 전체가 이 파일 하나에 담겨 있다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드 전용 (메신저 UX 표준)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ── 데모 모드: 서버 없이 실행 (한톡봇이 답장해 줌) ─────────
  // 연락처 매칭 테스트: 아래 번호를 기기 연락처에 저장해 보세요.
  final transport = InMemoryChatTransport(seedFakeUsers: [
    (nickname: '김철수', phoneNumber: '010-1111-2222'),
    (nickname: '이영희', phoneNumber: '010-3333-4444'),
  ]);

  // ── Firebase 모드로 전환하려면 위를 지우고: ──────────────
  // await Firebase.initializeApp();
  // final transport = FirebaseChatTransport(); // retention: ServerRetention.retain(days: 3) 옵션

  // 기기 언어에 맞는 정책 페이지 선택 (ko 기본, en/ja/zh 지원)
  final lang = PlatformDispatcher.instance.locale.languageCode;
  final suffix = switch (lang) {
    'en' => '.en',
    'ja' => '.ja',
    'zh' => '.zh',
    _ => '', // 한국어(기본)
  };
  const base = 'https://clapbin78.github.io/HanTalk';

  await HanChat.configure(HanChatConfig(
    transport: transport,
    // 기본은 기기에 계속 보관(일반 메신저처럼). 서버는 어떤 경우에도 메시지를
    // 보관하지 않는다. 사용자가 설정에서 '사라지는 메시지'(24시간/7일)를 켤 수 있음.
    localRetention: const RetentionPolicy.keepForever(),
    // 약관은 껍데기 앱 소유 (docs/ → GitHub Pages). 기기 언어별 페이지 주입.
    privacyPolicyUrl: Uri.parse('$base/privacy$suffix.html'),
    termsOfServiceUrl: Uri.parse('$base/terms$suffix.html'),
    serviceName: '한톡',
    appId: 'com.hantalk.app', // 임티샵 옵션 결제 확인용 식별자 (서버 licenses/{appId})
    // 🚩 숨겨진 기능들 (구조·테스트 완비, 때가 되면 켜기만):
    // paidEmoticonsEnabled: true,  // Phase 3: 이모티콘 유료 판매
    // aiAssistantEnabled: true,    // Phase 4: AI 답장 추천
    // translationService: MyAITranslator(), // Phase 4: AI 번역 (기본은 ML Kit 무료)
  ));

  runApp(const HanTalkApp());
}

class HanTalkApp extends StatelessWidget {
  const HanTalkApp({super.key});

  static const _brand = Color(0xFF2E9E5B); // 한톡 그린

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한톡',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _brand),
        useMaterial3: true,
        // iOS 느낌: 화면 전환 애니메이션을 쿠퍼티노(밀어서 넘기기)로
        pageTransitionsTheme: PageTransitionsTheme(builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        }),
      ),
      // 다국어: 기기 언어 자동 (ko/en/ja/zh)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
      ],
      // 오프라인 시 하단에 얇은 배너
      home: const OfflineBanner(child: _RootWithSplash()),
    );
  }
}

/// 앱 로딩(스플래시) — 브랜드 노출 후 부드럽게 전환
class _RootWithSplash extends StatefulWidget {
  const _RootWithSplash();

  @override
  State<_RootWithSplash> createState() => _RootWithSplashState();
}

class _RootWithSplashState extends State<_RootWithSplash> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const HanChatRootView(),
      AnimatedOpacity(
        opacity: _showSplash ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        child: IgnorePointer(
          ignoring: !_showSplash,
          child: Container(
            color: HanTalkApp._brand,
            alignment: Alignment.center,
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Text('💬', style: TextStyle(fontSize: 72)),
              SizedBox(height: 8),
              Text('한톡',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 4),
              Text('서버에 남지 않는 대화',
                  style: TextStyle(fontSize: 15, color: Colors.white70)),
            ]),
          ),
        ),
      ),
    ]);
  }
}
