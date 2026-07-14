import Foundation
import HanChatCore

/// SDK 설정. 호스트 앱이 configure 시점에 넘긴다.
public struct HanChatConfiguration: Sendable {
    /// 백엔드 구현 (HanChatFirebase의 FirebaseChatTransport, 자체 서버 구현체, 테스트용 InMemory 등)
    public var transport: any ChatTransport
    /// 로컬(기기) 메시지 보관 정책. 기본 24시간 자동삭제.
    public var localRetention: RetentionPolicy
    /// 개인정보처리방침 / 이용약관 URL — **호스트(껍데기) 앱이 소유**하고 SDK엔 주입만 한다.
    /// 둘 다 nil이면 SDK는 동의 화면을 건너뛴다 (호스트 앱이 자체 약관 플로우를 이미 가진 경우).
    /// 기존 앱에 붙일 땐: 그 앱의 약관에 채팅 관련 조항만 추가하고, 그 URL을 넣거나 nil로 두면 됨.
    public var privacyPolicyURL: URL?
    public var termsOfServiceURL: URL?

    /// SDK가 자체 동의 화면을 보여줄지 여부
    public var hasPolicies: Bool { privacyPolicyURL != nil && termsOfServiceURL != nil }
    /// 서비스 표시 이름
    public var serviceName: String
    /// ATT(앱 추적 투명성) 권한 요청 여부. 광고/추적 SDK를 쓰지 않으면 false 권장.
    public var requestsAppTracking: Bool
    /// 테스트/프리뷰용 인메모리 DB 사용
    public var inMemoryStorage: Bool
    /// 이모티콘 갤러리 저장소 (Firebase 구현 또는 자체 서버 구현으로 교체 가능)
    public var emoticonStore: any EmoticonStore
    /// 결제 게이트웨이. Phase 3에서 IAP 코인 구현으로 교체.
    public var paymentGateway: any PaymentGateway
    /// 🚩 유료 이모티콘 기능 스위치. 로직·테스트는 살아있고 UI 노출만 막는다.
    /// Phase 3(이모티콘 샵 유료화) 때 true로 켠다.
    public var paidEmoticonsEnabled: Bool

    public init(
        transport: any ChatTransport,
        localRetention: RetentionPolicy = .oneDay,
        privacyPolicyURL: URL? = nil,
        termsOfServiceURL: URL? = nil,
        serviceName: String = "한톡",
        requestsAppTracking: Bool = false,
        inMemoryStorage: Bool = false,
        emoticonStore: any EmoticonStore = InMemoryEmoticonStore(),
        paymentGateway: any PaymentGateway = StubPaymentGateway(),
        paidEmoticonsEnabled: Bool = false
    ) {
        self.transport = transport
        self.localRetention = localRetention
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfServiceURL = termsOfServiceURL
        self.serviceName = serviceName
        self.requestsAppTracking = requestsAppTracking
        self.inMemoryStorage = inMemoryStorage
        self.emoticonStore = emoticonStore
        self.paymentGateway = paymentGateway
        self.paidEmoticonsEnabled = paidEmoticonsEnabled
    }
}

/// 컴포지션 루트. 모든 의존성이 여기서 조립된다 (외부 DI 라이브러리 불필요).
public final class HanChatClient: @unchecked Sendable {
    public let configuration: HanChatConfiguration

    // Repositories
    public let userRepository: any UserRepository
    public let friendRepository: any FriendRepository
    public let roomRepository: any ChatRoomRepository
    public let messageRepository: any MessageRepository
    public let emoticonRepository: any EmoticonRepository

    // UseCases (UI 레이어는 이것만 사용한다 — Repository 직접 접근 금지)
    public let registerUser: RegisterUserUseCase
    public let syncContacts: SyncContactsUseCase
    public let createRoom: CreateChatRoomUseCase
    public let sendMessage: SendMessageUseCase
    public let purgeExpired: PurgeExpiredMessagesUseCase
    public let getCurrentUser: GetCurrentUserUseCase
    public let getFriends: GetFriendsUseCase
    public let observeRooms: ObserveChatRoomsUseCase
    public let observeMessages: ObserveMessagesUseCase
    public let uploadEmoticon: UploadEmoticonUseCase
    public let browseEmoticons: BrowseEmoticonsUseCase
    public let getMyEmoticons: GetMyEmoticonsUseCase
    public let acquireEmoticon: AcquireEmoticonUseCase

    private let syncEngine: MessageSyncEngine

    public init(configuration: HanChatConfiguration) throws {
        self.configuration = configuration

        let container = try HanChatSchema.makeContainer(inMemory: configuration.inMemoryStorage)
        let store = LocalStore(modelContainer: container)
        let notifier = ChangeNotifier()
        let transport = configuration.transport

        let users = DefaultUserRepository(store: store, transport: transport)
        let friends = DefaultFriendRepository(store: store, transport: transport, notifier: notifier)
        let rooms = DefaultChatRoomRepository(store: store, notifier: notifier)
        let messages = DefaultMessageRepository(store: store, transport: transport, notifier: notifier)
        let emoticons = DefaultEmoticonRepository(
            store: store,
            gallery: configuration.emoticonStore,
            notifier: notifier
        )

        self.userRepository = users
        self.friendRepository = friends
        self.roomRepository = rooms
        self.messageRepository = messages
        self.emoticonRepository = emoticons

        self.registerUser = RegisterUserUseCase(users: users)
        self.syncContacts = SyncContactsUseCase(friends: friends)
        self.createRoom = CreateChatRoomUseCase(rooms: rooms)
        self.sendMessage = SendMessageUseCase(messages: messages)
        self.purgeExpired = PurgeExpiredMessagesUseCase(
            messages: messages,
            policy: configuration.localRetention
        )
        self.getCurrentUser = GetCurrentUserUseCase(users: users)
        self.getFriends = GetFriendsUseCase(friends: friends)
        self.observeRooms = ObserveChatRoomsUseCase(rooms: rooms)
        self.observeMessages = ObserveMessagesUseCase(messages: messages)
        self.uploadEmoticon = UploadEmoticonUseCase(
            emoticons: emoticons,
            users: users,
            allowPaid: configuration.paidEmoticonsEnabled
        )
        self.browseEmoticons = BrowseEmoticonsUseCase(emoticons: emoticons)
        self.getMyEmoticons = GetMyEmoticonsUseCase(emoticons: emoticons)
        self.acquireEmoticon = AcquireEmoticonUseCase(
            emoticons: emoticons,
            users: users,
            payment: configuration.paymentGateway
        )

        self.syncEngine = MessageSyncEngine(store: store, transport: transport, notifier: notifier)
    }

    /// 등록된 사용자로 수신 동기화 시작 + 만료 메시지 정리.
    /// 앱 시작 및 포그라운드 진입 시 호출.
    public func start() async {
        if let me = try? await userRepository.currentUser() {
            syncEngine.start(userID: me.id)
        }
        _ = try? await purgeExpired()
    }

    public func stop() {
        syncEngine.stop()
    }
}
