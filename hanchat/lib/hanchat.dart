/// hanchat — 어떤 Flutter 앱에도 붙는 채팅 SDK.
///
/// 레이어 (의존 방향은 항상 core로만):
/// - core: 순수 Dart 도메인 (엔티티·UseCase·추상 Repository)
/// - data: 로컬 저장(sqflite) + 우체통 프로토콜(ChatTransport) 구현
/// - ui:   완성형 채팅 화면 (Flutter 위젯)
library hanchat;

// Core — Domain
export 'src/core/entities.dart';
export 'src/core/errors.dart';
export 'src/core/retention.dart';
export 'src/core/repositories.dart';
export 'src/core/usecases.dart';
export 'src/core/entitlement.dart';
export 'src/core/support_content.dart';
export 'src/core/profile.dart';

// Data — 우체통 프로토콜과 기본 구현
export 'src/data/chat_transport.dart';
export 'src/data/in_memory_transport.dart';
export 'src/data/emoticon_store.dart';
export 'src/data/phone_number_hasher.dart';
export 'src/data/client.dart';
export 'src/data/read_receipt_setting.dart';

// UI — 완성형 채팅 화면
export 'src/ui/root.dart';
export 'src/ui/theme.dart';
export 'src/ui/l10n.dart';
export 'src/ui/translatable_text.dart';
export 'src/ui/drawing.dart' show DrawingReplaySetting, DrawingReplayView, DrawingThumbnail;
