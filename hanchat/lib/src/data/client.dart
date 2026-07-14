import 'package:sqflite/sqflite.dart';

import '../core/entitlement.dart';
import '../core/profile.dart';
import '../core/report.dart';
import '../core/repositories.dart';
import '../core/retention.dart';
import '../core/support_content.dart';
import '../core/usecases.dart';
import 'chat_transport.dart';
import 'emoticon_store.dart';
import 'local_store.dart';
import 'repositories_impl.dart';
import 'sync_engine.dart';

/// SDK 설정. 호스트 앱이 configure 시점에 넘긴다.
class HanChatConfig {
  /// 백엔드 (hanchat_firebase의 FirebaseChatTransport, 자체 서버, 테스트용 InMemory 등)
  final ChatTransport transport;

  /// 로컬(기기) 메시지 보관 정책. 기본 24시간 자동삭제.
  final RetentionPolicy localRetention;

  /// 약관 URL — **호스트 앱 소유**, null이면 SDK가 동의 화면을 건너뜀.
  final Uri? privacyPolicyUrl;
  final Uri? termsOfServiceUrl;
  final String serviceName;

  /// 이모티콘 갤러리 저장소 (교체 가능)
  final EmoticonStore emoticonStore;

  /// 결제 게이트웨이 — Phase 3에서 IAP 구현으로 교체
  final PaymentGateway paymentGateway;

  /// 🚩 유료 이모티콘 스위치 (Phase 3에서 켬)
  final bool paidEmoticonsEnabled;

  /// AI 서비스 — Phase 4에서 실제 구현으로 교체
  final AIAssistantService aiService;

  /// 🚩 AI 답장 추천 스위치 (Phase 4에서 켬)
  final bool aiAssistantEnabled;

  /// 번역 — null이면 UI가 ML Kit 온디바이스 번역 사용 (무료).
  final TranslationService? translationService;

  /// 이 앱의 식별자 — 임티샵 옵션(업로드/판매) 결제 여부를 서버가 이걸로 확인.
  final String appId;

  /// 라이선스 서버. 갤러리 "사용"은 검증 없이 모든 앱 기본 제공이지만,
  /// "업로드/판매" UI는 이 서비스가 결제 확인을 해줘야만 노출된다.
  final EntitlementService entitlementService;

  /// 공지/FAQ 서비스 (버전 캐시). 실서비스는 Firebase 구현 주입.
  final SupportContentService supportService;

  /// 관리자 모드 (비번 검증은 Cloud Function). 실서비스는 Firebase 구현 주입.
  final AdminService adminService;

  /// 프로필 발행/조회 (사진·배경). 실서비스는 Firebase(Storage) 구현 주입.
  final ProfileService profileService;

  /// 신고 접수 (UGC 안전 요건). 실서비스는 Firebase 구현 주입.
  final ReportService reportService;

  /// DB 경로 (기본: 앱 데이터 디렉터리의 hanchat.db). 테스트에서 인메모리 지정.
  final String? databasePath;
  final DatabaseFactory? databaseFactory;

  HanChatConfig({
    required this.transport,
    this.localRetention = RetentionPolicy.oneDay,
    this.privacyPolicyUrl,
    this.termsOfServiceUrl,
    this.serviceName = '한톡',
    EmoticonStore? emoticonStore,
    PaymentGateway? paymentGateway,
    this.paidEmoticonsEnabled = false,
    AIAssistantService? aiService,
    this.aiAssistantEnabled = false,
    this.translationService,
    this.appId = 'demo',
    EntitlementService? entitlementService,
    SupportContentService? supportService,
    AdminService? adminService,
    ProfileService? profileService,
    ReportService? reportService,
    this.databasePath,
    this.databaseFactory,
  })  : emoticonStore = emoticonStore ?? InMemoryEmoticonStore(),
        paymentGateway = paymentGateway ?? StubPaymentGateway(),
        aiService = aiService ?? const StubAIAssistantService(),
        // 데모 기본값: 전 기능 체험. 실서비스는 Firebase 구현 주입 필수.
        entitlementService =
            entitlementService ?? const StubEntitlementService.fullAccess(),
        supportService = supportService ?? StubSupportContentService(),
        adminService = adminService ?? StubAdminService(),
        profileService = profileService ?? InMemoryProfileService(),
        reportService = reportService ?? InMemoryReportService();

  bool get hasPolicies => privacyPolicyUrl != null && termsOfServiceUrl != null;
}

/// 컴포지션 루트 — 모든 의존성이 여기서 조립된다 (외부 DI 패키지 불필요).
/// UI 레이어는 이 클라이언트의 **UseCase만** 사용한다.
class HanChatClient {
  final HanChatConfig config;

  // Repositories (호스트 앱 고급 사용자용 — SDK UI는 사용 금지, archcheck가 감시)
  final UserRepository userRepository;
  final FriendRepository friendRepository;
  final ChatRoomRepository roomRepository;
  final MessageRepository messageRepository;
  final EmoticonRepository emoticonRepository;

  // UseCases — UI의 유일한 진입점
  final RegisterUserUseCase registerUser;
  final GetCurrentUserUseCase getCurrentUser;
  final UpdateProfileImagesUseCase updateProfileImages;
  final UpdateStatusMessageUseCase updateStatusMessage;
  final GetProfileUseCase getProfile;
  final PublishProfileUseCase publishProfile;
  final SubmitReportUseCase submitReport;
  final AdminModerationUseCase adminModeration;
  final SyncContactsUseCase syncContacts;
  final GetFriendsUseCase getFriends;
  final ManageFriendsUseCase manageFriends;
  final CreateChatRoomUseCase createRoom;
  final ObserveChatRoomsUseCase observeRooms;
  final SendMessageUseCase sendMessage;
  final ObserveMessagesUseCase observeMessages;
  final MarkRoomReadUseCase markRoomRead;
  final PurgeExpiredMessagesUseCase purgeExpired;
  final UploadEmoticonUseCase uploadEmoticon;
  final BrowseEmoticonsUseCase browseEmoticons;
  final GetMyEmoticonsUseCase getMyEmoticons;
  final AcquireEmoticonUseCase acquireEmoticon;
  final SuggestRepliesUseCase suggestReplies;

  /// 커스텀 번역 서비스가 주입된 경우에만 존재 (null → UI가 ML Kit 사용)
  final TranslateTextUseCase? translateText;

  /// 임티샵 옵션 권한 (서버 확인, 캐시됨)
  final GetShopEntitlementUseCase getShopEntitlement;

  /// 공지/FAQ 조회 + 관리자
  final GetSupportContentUseCase getSupportContent;
  final UnlockAdminUseCase unlockAdmin;
  final PostSupportUseCase postSupport;

  final LocalStore _store;
  final MessageSyncEngine _syncEngine;

  HanChatClient._({
    required this.config,
    required LocalStore store,
    required MessageSyncEngine syncEngine,
    required this.userRepository,
    required this.friendRepository,
    required this.roomRepository,
    required this.messageRepository,
    required this.emoticonRepository,
  })  : _store = store,
        _syncEngine = syncEngine,
        registerUser = RegisterUserUseCase(userRepository),
        getCurrentUser = GetCurrentUserUseCase(userRepository),
        updateProfileImages = UpdateProfileImagesUseCase(userRepository),
        updateStatusMessage = UpdateStatusMessageUseCase(userRepository),
        getProfile = GetProfileUseCase(config.profileService),
        publishProfile = PublishProfileUseCase(config.profileService),
        submitReport = SubmitReportUseCase(config.reportService),
        adminModeration = AdminModerationUseCase(config.reportService),
        syncContacts = SyncContactsUseCase(friendRepository),
        getFriends = GetFriendsUseCase(friendRepository),
        manageFriends = ManageFriendsUseCase(friendRepository),
        createRoom = CreateChatRoomUseCase(roomRepository),
        observeRooms = ObserveChatRoomsUseCase(roomRepository),
        sendMessage = SendMessageUseCase(messageRepository),
        observeMessages = ObserveMessagesUseCase(messageRepository),
        markRoomRead = MarkRoomReadUseCase(messageRepository),
        purgeExpired =
            PurgeExpiredMessagesUseCase(messageRepository, config.localRetention),
        uploadEmoticon = UploadEmoticonUseCase(emoticonRepository, userRepository,
            allowPaid: config.paidEmoticonsEnabled),
        browseEmoticons = BrowseEmoticonsUseCase(emoticonRepository),
        getMyEmoticons = GetMyEmoticonsUseCase(emoticonRepository),
        acquireEmoticon = AcquireEmoticonUseCase(
            emoticonRepository, userRepository, config.paymentGateway),
        suggestReplies =
            SuggestRepliesUseCase(config.aiService, enabled: config.aiAssistantEnabled),
        translateText = config.translationService == null
            ? null
            : TranslateTextUseCase(config.translationService!),
        getShopEntitlement = GetShopEntitlementUseCase(
            config.entitlementService,
            appId: config.appId),
        getSupportContent = GetSupportContentUseCase(config.supportService),
        unlockAdmin = UnlockAdminUseCase(config.adminService),
        postSupport = PostSupportUseCase(config.supportService);

  static Future<HanChatClient> create(HanChatConfig config) async {
    final path = config.databasePath ?? '${await getDatabasesPath()}/hanchat.db';
    final store = await LocalStore.open(path: path, factory: config.databaseFactory);
    final notifier = ChangeNotifierBus();

    return HanChatClient._(
      config: config,
      store: store,
      syncEngine: MessageSyncEngine(store, config.transport, notifier),
      userRepository: DefaultUserRepository(store, config.transport),
      friendRepository: DefaultFriendRepository(store, config.transport, notifier),
      roomRepository: DefaultChatRoomRepository(store, notifier),
      messageRepository: DefaultMessageRepository(store, config.transport, notifier),
      emoticonRepository:
          DefaultEmoticonRepository(store, config.emoticonStore, notifier),
    );
  }

  /// 등록된 사용자로 수신 동기화 시작 + 만료 메시지 정리.
  /// 앱 시작 및 포그라운드 진입 시 호출.
  Future<void> start() async {
    final me = await _store.currentUser();
    if (me != null) _syncEngine.start(me.id);
    try {
      await purgeExpired();
    } catch (_) {}
  }

  Future<void> stop() => _syncEngine.stop();
}

/// SDK 진입점. 호스트 앱은 이 한 줄이면 된다:
/// ```dart
/// await HanChat.configure(HanChatConfig(transport: ...));
/// ```
class HanChat {
  HanChat._();

  static HanChatClient? _client;

  static HanChatClient get client =>
      _client ?? (throw StateError('HanChat.configure()를 먼저 호출해 주세요.'));

  static Future<HanChatClient> configure(HanChatConfig config) async {
    final client = await HanChatClient.create(config);
    _client = client;
    await client.start();
    return client;
  }
}
