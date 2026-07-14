import Foundation

/// UI 문자열 중앙 관리 — 모든 사용자 노출 문자열은 여기서만 꺼내 쓴다.
/// 번역은 Resources/Localizable.xcstrings (ko 원문 / en·ja·zh-Hans 번역).
/// 새 언어 추가 = 카탈로그에 언어만 추가하면 끝 (코드 수정 불필요).
enum L {
    // 공통
    static var cancel: String { String(localized: "취소", bundle: .module) }
    static var ok: String { String(localized: "확인", bundle: .module) }
    static var notice: String { String(localized: "알림", bundle: .module) }
    static var close: String { String(localized: "닫기", bundle: .module) }
    static var send: String { String(localized: "보내기", bundle: .module) }
    static var next: String { String(localized: "다음", bundle: .module) }
    static var unknown: String { String(localized: "알 수 없음", bundle: .module) }

    // 탭
    static var tabFriends: String { String(localized: "친구", bundle: .module) }
    static var tabChats: String { String(localized: "채팅", bundle: .module) }
    static var tabEmoticons: String { String(localized: "이모티콘", bundle: .module) }
    static var tabSettings: String { String(localized: "설정", bundle: .module) }

    // 온보딩
    static func welcomeTitle(_ serviceName: String) -> String {
        String(localized: "\(serviceName)에 오신 걸 환영해요", bundle: .module)
    }
    static var welcomeSubtitle: String { String(localized: "메시지는 서버에 남지 않고,\n기기에서도 24시간 뒤 사라져요.", bundle: .module) }
    static var agreeTerms: String { String(localized: "이용약관 동의 (필수)", bundle: .module) }
    static var agreePrivacy: String { String(localized: "개인정보 수집·이용 동의 (필수)", bundle: .module) }
    static var view: String { String(localized: "보기", bundle: .module) }
    static var agreeAndStart: String { String(localized: "동의하고 시작하기", bundle: .module) }
    static var terms: String { String(localized: "이용약관", bundle: .module) }
    static var privacyPolicy: String { String(localized: "개인정보처리방침", bundle: .module) }
    static var profile: String { String(localized: "프로필", bundle: .module) }
    static var nickname: String { String(localized: "닉네임", bundle: .module) }
    static var phonePlaceholder: String { String(localized: "전화번호 (예: 01012345678)", bundle: .module) }
    static var phonePrivacyFooter: String { String(localized: "전화번호 원본은 서버로 전송되지 않아요. 친구 찾기에는 암호화된 해시만 사용됩니다.", bundle: .module) }
    static var register: String { String(localized: "등록", bundle: .module) }
    static var createProfile: String { String(localized: "프로필 만들기", bundle: .module) }
    static var notifTitle: String { String(localized: "새 메시지를 놓치지 마세요", bundle: .module) }
    static var notifSubtitle: String { String(localized: "친구가 보낸 메시지가 도착하면 알려드려요.\n푸시에 메시지 내용은 담기지 않아요.", bundle: .module) }
    static var enableNotifications: String { String(localized: "알림 켜기", bundle: .module) }
    static var maybeLater: String { String(localized: "나중에 할게요", bundle: .module) }

    // 친구
    static var myProfile: String { String(localized: "내 프로필", bundle: .module) }
    static func friendsCount(_ n: Int) -> String { String(localized: "친구 \(n)", bundle: .module) }
    static var noFriendsYet: String { String(localized: "아직 친구가 없어요. 연락처를 동기화해 보세요!", bundle: .module) }
    static var syncAllContacts: String { String(localized: "연락처 전체 등록", bundle: .module) }
    static var syncManualContacts: String { String(localized: "직접 선택해서 등록", bundle: .module) }
    static var noCandidatesTitle: String { String(localized: "가입한 친구가 없어요", bundle: .module) }
    static var noCandidatesSubtitle: String { String(localized: "연락처 중 아직 가입한 사람이 없네요.", bundle: .module) }
    static var selectFriends: String { String(localized: "친구 선택", bundle: .module) }
    static func addSelected(_ n: Int) -> String { String(localized: "등록 (\(n))", bundle: .module) }
    static var contactsPermissionNeeded: String { String(localized: "연락처 권한이 필요해요. 설정에서 허용해 주세요.", bundle: .module) }

    // 채팅 목록
    static var groupChat: String { String(localized: "단톡방", bundle: .module) }
    static var startConversation: String { String(localized: "대화를 시작해 보세요", bundle: .module) }
    static var noChatsTitle: String { String(localized: "채팅이 없어요", bundle: .module) }
    static var noChatsSubtitle: String { String(localized: "친구 탭에서 친구를 눌러 대화를 시작하세요.", bundle: .module) }
    static var roomName: String { String(localized: "방 이름", bundle: .module) }
    static var roomNamePlaceholder: String { String(localized: "예: 불금 모임 🍻", bundle: .module) }
    static var inviteFriends: String { String(localized: "초대할 친구 (2명 이상)", bundle: .module) }
    static var newGroupChat: String { String(localized: "단톡방 만들기", bundle: .module) }
    static var create: String { String(localized: "만들기", bundle: .module) }

    // 채팅방
    static var retentionNotice: String { String(localized: "⏳ 메시지는 24시간 뒤 자동으로 사라져요", bundle: .module) }
    static var messagePlaceholder: String { String(localized: "메시지 입력", bundle: .module) }
    static var sending: String { String(localized: "전송 중", bundle: .module) }
    static var sendFailed: String { String(localized: "실패", bundle: .module) }
    static var myEmoticons: String { String(localized: "내 이모티콘", bundle: .module) }
    static var emptyCollectionTitle: String { String(localized: "보관함이 비어있어요", bundle: .module) }
    static var emptyCollectionSubtitle: String { String(localized: "이모티콘 탭에서 받아오거나 직접 그려보세요!", bundle: .module) }

    // 이모티콘 갤러리
    static var noEmoticonsTitle: String { String(localized: "아직 이모티콘이 없어요", bundle: .module) }
    static var noEmoticonsSubtitle: String { String(localized: "첫 이모티콘을 그려서 올려보세요!", bundle: .module) }
    static var owned: String { String(localized: "보관함에 있음", bundle: .module) }
    static var getFree: String { String(localized: "받기", bundle: .module) }
    static func priceTag(_ won: Int) -> String { String(localized: "₩\(won)", bundle: .module) }
    static var name: String { String(localized: "이름", bundle: .module) }
    static var emoticonNamePlaceholder: String { String(localized: "예: 두근두근", bundle: .module) }
    static var priceSection: String { String(localized: "가격 (원, 0 = 무료)", bundle: .module) }
    static var uploadDisclosure: String { String(localized: "올리면 모든 사용자에게 공개되고, 누구나 채팅에서 쓸 수 있어요. 저작권은 만든 사람(나)에게 있어요.", bundle: .module) }
    static var uploadToGallery: String { String(localized: "갤러리에 올리기", bundle: .module) }
    static var upload: String { String(localized: "올리기", bundle: .module) }

    // 설정
    static var chatSection: String { String(localized: "채팅", bundle: .module) }
    static var drawingReplayToggle: String { String(localized: "그림 그리는 과정 재생", bundle: .module) }
    static var drawingReplayFooter: String { String(localized: "끄면 완성된 그림만 바로 표시돼요.", bundle: .module) }
    static var retentionSection: String { String(localized: "메시지 보관", bundle: .module) }
    static var autoDelete: String { String(localized: "자동 삭제", bundle: .module) }
    static var never: String { String(localized: "안 함", bundle: .module) }
    static func afterHours(_ h: Int) -> String { String(localized: "\(h)시간 후", bundle: .module) }
    static var retentionFooter: String { String(localized: "메시지는 서버에 저장되지 않으며, 이 기기에서도 위 기간이 지나면 자동으로 삭제됩니다.", bundle: .module) }
    static var policiesSection: String { String(localized: "약관 및 정책", bundle: .module) }

    // 그림판
    static var drawTitle: String { String(localized: "그림 그리기", bundle: .module) }
    static var replayA11y: String { String(localized: "그리는 과정 재생", bundle: .module) }
}
