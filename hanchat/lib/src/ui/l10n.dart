import 'package:flutter/widgets.dart';

/// SDK 내장 다국어 (ko/en/ja/zh — 새 언어는 맵에 열만 추가).
/// Swift 버전의 String Catalog와 같은 번역을 사용한다.
/// UseCase가 던지는 검증 에러도 l10n 키('error.*')로 와서 여기서 번역된다.
class HanChatL10n {
  final String _lang;
  const HanChatL10n(this._lang);

  static HanChatL10n of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
    return HanChatL10n(_table.containsKey(code) ? code : 'en');
  }

  String t(String key) => _strings[key]?[_langIndex] ?? _strings[key]?[1] ?? key;

  /// UseCase 예외 메시지(키 또는 일반 문자열)를 사용자 문구로.
  String error(Object e) {
    final key = e.toString();
    return _strings.containsKey(key) ? t(key) : key;
  }

  int get _langIndex => _table[_lang] ?? 1;

  static const _table = {'ko': 0, 'en': 1, 'ja': 2, 'zh': 3};

  // [ko, en, ja, zh-Hans]
  static const Map<String, List<String>> _strings = {
    // 공통
    'cancel': ['취소', 'Cancel', 'キャンセル', '取消'],
    'ok': ['확인', 'OK', 'OK', '确定'],
    'notice': ['알림', 'Notice', 'お知らせ', '提示'],
    'close': ['닫기', 'Close', '閉じる', '关闭'],
    'send': ['보내기', 'Send', '送信', '发送'],
    'next': ['다음', 'Next', '次へ', '下一步'],
    'unknown': ['알 수 없음', 'Unknown', '不明', '未知'],
    // 탭
    'tab.friends': ['친구', 'Friends', '友だち', '朋友'],
    'tab.chats': ['채팅', 'Chats', 'チャット', '聊天'],
    'tab.emoticons': ['이모티콘', 'Emoticons', 'スタンプ', '表情'],
    'tab.settings': ['설정', 'Settings', '設定', '设置'],
    // 접근 권한 안내 (한국 정보통신망법 — 전 지역 공통 노출)
    'perm.title': ['앱 접근 권한 안내', 'App Permissions Notice', 'アプリのアクセス権限について', '应用权限说明'],
    'perm.subtitle': [
      '서비스 이용을 위해 아래 접근 권한을 사용해요.',
      'This service uses the permissions below.',
      'サービス利用のため、以下のアクセス権限を使用します。',
      '本服务将使用以下权限。'
    ],
    'perm.notif': ['알림 (선택)', 'Notifications (optional)', '通知（任意）', '通知（可选）'],
    'perm.notifDesc': ['새 메시지 도착 알림', 'Alerts for new messages', '新着メッセージのお知らせ', '新消息提醒'],
    'perm.contacts': ['연락처 (선택)', 'Contacts (optional)', '連絡先（任意）', '通讯录（可选）'],
    'perm.contactsDesc': ['가입한 친구 찾기', 'Finding friends who joined', '登録済みの友だち検索', '查找已加入的朋友'],
    'perm.footer': [
      '선택 접근권한은 허용하지 않아도 서비스를 이용할 수 있어요.',
      "You can use the service even if you don't allow optional permissions.",
      '任意のアクセス権限は許可しなくてもサービスを利用できます。',
      '即使不允许可选权限，也可以使用本服务。'
    ],
    // 온보딩
    'onboard.welcome': ['%@에 오신 걸 환영해요', 'Welcome to %@', '%@へようこそ', '欢迎来到%@'],
    'onboard.subtitle': [
      '메시지는 서버에 남지 않아요.\n원하면 사라지는 메시지로 자동삭제할 수 있어요.',
      'Messages never stay on our servers.\nTurn on disappearing messages to auto-delete them too.',
      'メッセージはサーバーに残りません。\n消えるメッセージで自動削除もできます。',
      '消息不会保存在服务器上。\n可开启“消失的消息”实现自动删除。'
    ],
    'onboard.agreeTerms': ['이용약관 동의 (필수)', 'Agree to Terms of Service (required)', '利用規約に同意（必須）', '同意服务条款（必填）'],
    'onboard.agreePrivacy': ['개인정보 수집·이용 동의 (필수)', 'Agree to Privacy Policy (required)', '個人情報の取扱いに同意（必須）', '同意隐私政策（必填）'],
    'onboard.view': ['보기', 'View', '見る', '查看'],
    'onboard.start': ['동의하고 시작하기', 'Agree & Start', '同意して始める', '同意并开始'],
    'terms': ['이용약관', 'Terms of Service', '利用規約', '服务条款'],
    'privacy': ['개인정보처리방침', 'Privacy Policy', 'プライバシーポリシー', '隐私政策'],
    'profile': ['프로필', 'Profile', 'プロフィール', '个人资料'],
    'profile.create': ['프로필 만들기', 'Create Profile', 'プロフィール作成', '创建个人资料'],
    'profile.edit': ['프로필 수정', 'Edit Profile', 'プロフィール編集', '编辑资料'],
    'profile.removePhotos': ['사진 모두 지우기', 'Remove all photos', '写真をすべて削除', '删除所有照片'],
    'profile.status': ['상태메시지', 'Status Message', 'ステータスメッセージ', '状态消息'],
    'profile.statusHint': ['상태메시지를 입력해 보세요', 'Set a status message', 'ステータスメッセージを入力', '设置状态消息'],
    'nickname': ['닉네임', 'Nickname', 'ニックネーム', '昵称'],
    'phone.placeholder': ['전화번호 (예: 01012345678)', 'Phone number (e.g. 5551234567)', '電話番号（例: 09012345678）', '电话号码（例：13800138000）'],
    'phone.privacy': [
      '전화번호 원본은 서버로 전송되지 않아요. 친구 찾기에는 암호화된 해시만 사용됩니다.',
      'Your phone number never leaves your device — only an encrypted hash is used to find friends.',
      '電話番号そのものはサーバーに送信されません。友だち検索には暗号化されたハッシュのみ使用されます。',
      '手机号原文不会上传到服务器，查找朋友仅使用加密哈希值。'
    ],
    'register': ['등록', 'Sign Up', '登録', '注册'],
    'notif.title': ['새 메시지를 놓치지 마세요', 'Never miss a message', '新着メッセージを見逃さない', '不错过任何新消息'],
    'notif.subtitle': [
      '친구가 보낸 메시지가 도착하면 알려드려요.\n푸시에 메시지 내용은 담기지 않아요.',
      "We'll notify you when messages arrive.\nNotifications never include message content.",
      'メッセージが届いたらお知らせします。\n通知に本文は含まれません。',
      '收到消息时会通知您。\n通知中不包含消息内容。'
    ],
    'notif.enable': ['알림 켜기', 'Enable Notifications', '通知をオンにする', '开启通知'],
    'notif.later': ['나중에 할게요', 'Maybe Later', 'あとで', '以后再说'],
    // 친구
    'friends.my': ['내 프로필', 'My Profile', 'マイプロフィール', '我的资料'],
    'friends.count': ['친구 %d', 'Friends (%d)', '友だち %d', '朋友 %d'],
    'friends.empty': ['아직 친구가 없어요. 연락처를 동기화해 보세요!', 'No friends yet — try syncing your contacts!', 'まだ友だちがいません。連絡先を同期してみましょう！', '还没有朋友，试试同步通讯录吧！'],
    'friends.syncAll': ['연락처 전체 등록', 'Add All from Contacts', '連絡先を全員登録', '添加全部联系人'],
    'friends.syncManual': ['직접 선택해서 등록', 'Choose Who to Add', '選んで登録', '手动选择添加'],
    'friends.noCandidates': ['가입한 친구가 없어요', 'No registered friends found', '登録済みの友だちがいません', '没有已注册的朋友'],
    'friends.noCandidatesDesc': ['연락처 중 아직 가입한 사람이 없네요.', 'None of your contacts have joined yet.', '連絡先の中にまだ利用者がいません。', '通讯录中还没有人加入。'],
    'friends.select': ['친구 선택', 'Select Friends', '友だちを選択', '选择朋友'],
    'friends.add': ['등록 (%d)', 'Add (%d)', '登録 (%d)', '添加 (%d)'],
    'friends.permNeeded': ['연락처 권한이 필요해요. 설정에서 허용해 주세요.', 'Contacts permission is required. Please allow it in Settings.', '連絡先へのアクセス許可が必要です。設定で許可してください。', '需要通讯录权限，请在设置中允许。'],
    'friends.addSheetTitle': ['친구 추가', 'Add Friends', '友だちを追加', '添加朋友'],
    // 채팅
    'chats.group': ['단톡방', 'Group Chat', 'グループチャット', '群聊'],
    'chats.start': ['대화를 시작해 보세요', 'Start a conversation', '会話を始めましょう', '开始聊天吧'],
    'chats.empty': ['채팅이 없어요', 'No chats yet', 'チャットがありません', '暂无聊天'],
    'chats.emptyDesc': ['친구 탭에서 친구를 눌러 대화를 시작하세요.', 'Tap a friend in the Friends tab to start chatting.', '友だちタブで友だちをタップして会話を始めましょう。', '在朋友标签页点击朋友开始聊天。'],
    'chats.roomName': ['방 이름', 'Room Name', 'ルーム名', '群名称'],
    'chats.roomNameHint': ['예: 불금 모임 🍻', 'e.g. Friday Night 🍻', '例: 金曜の集まり🍻', '例如：周五聚会🍻'],
    'chats.invite': ['초대할 친구 (2명 이상)', 'Invite Friends (2 or more)', '招待する友だち（2人以上）', '邀请朋友（2人及以上）'],
    'chats.newGroup': ['단톡방 만들기', 'New Group Chat', 'グループ作成', '创建群聊'],
    'chats.create': ['만들기', 'Create', '作成', '创建'],
    'room.retention': ['⏳ 메시지는 24시간 뒤 자동으로 사라져요', '⏳ Messages disappear after 24 hours', '⏳ メッセージは24時間後に自動で消えます', '⏳ 消息将在24小时后自动消失'],
    'room.disappear7d': ['⏳ 메시지는 7일 뒤 자동으로 사라져요', '⏳ Messages disappear after 7 days', '⏳ メッセージは7日後に自動で消えます', '⏳ 消息将在7天后自动消失'],
    'room.serverOnly': ['🔒 대화 내용은 서버에 저장되지 않아요', '🔒 Messages are never stored on our servers', '🔒 メッセージはサーバーに保存されません', '🔒 消息不会保存在服务器上'],
    'room.input': ['메시지 입력', 'Message', 'メッセージを入力', '输入消息'],
    'room.sending': ['전송 중', 'Sending', '送信中', '发送中'],
    'room.failed': ['실패', 'Failed', '失敗', '失败'],
    'room.myEmoticons': ['내 이모티콘', 'My Emoticons', 'マイスタンプ', '我的表情'],
    'room.read': ['읽음', 'Read', '既読', '已读'],
    'room.mute': ['알림 끄기', 'Mute', '通知オフ', '关闭提醒'],
    'room.unmute': ['알림 켜기', 'Unmute', '通知オン', '开启提醒'],
    'room.muted': ['이 방 알림을 껐어요', 'Muted this chat', 'このチャットをミュートしました', '已关闭该聊天提醒'],
    'room.unmuted': ['이 방 알림을 켰어요', 'Unmuted this chat', 'このチャットのミュートを解除しました', '已开启该聊天提醒'],
    'room.emptyCollection': ['보관함이 비어있어요', 'Your collection is empty', '保管箱が空です', '收藏夹是空的'],
    'room.emptyCollectionDesc': ['이모티콘 탭에서 받아오거나 직접 그려보세요!', 'Get some from the Emoticons tab, or draw your own!', 'スタンプタブで入手するか、自分で描いてみましょう！', '去表情标签页领取，或自己画一个吧！'],
    // 이모티콘
    'emo.empty': ['아직 이모티콘이 없어요', 'No emoticons yet', 'まだスタンプがありません', '还没有表情'],
    'emo.emptyDesc': ['첫 이모티콘을 그려서 올려보세요!', 'Draw and upload the first one!', '最初のスタンプを描いて投稿してみましょう！', '画一个并上传第一个表情吧！'],
    'emo.owned': ['보관함에 있음', 'Owned', '入手済み', '已拥有'],
    'emo.get': ['받기', 'Get', '入手', '领取'],
    'emo.price': ['₩%d', '₩%d', '₩%d', '₩%d'],
    'emo.name': ['이름', 'Name', '名前', '名称'],
    'emo.nameHint': ['예: 두근두근', 'e.g. Heartbeat', '例: ドキドキ', '例如：心动'],
    'emo.priceSection': ['가격 (원, 0 = 무료)', 'Price (KRW, 0 = free)', '価格（ウォン、0 = 無料）', '价格（韩元，0 = 免费）'],
    'emo.disclosure': [
      '올리면 모든 사용자에게 공개되고, 누구나 채팅에서 쓸 수 있어요. 저작권은 만든 사람(나)에게 있어요.',
      'Uploads are public — anyone can use them in chat. You keep the copyright.',
      '投稿するとすべてのユーザーに公開され、誰でもチャットで使えます。著作権は作者（あなた）にあります。',
      '上传后对所有用户公开，任何人都可在聊天中使用。版权归创作者（你）所有。'
    ],
    'emo.uploadTitle': ['갤러리에 올리기', 'Upload to Gallery', 'ギャラリーに投稿', '上传到画廊'],
    'emo.upload': ['올리기', 'Upload', '投稿', '上传'],
    // 설정
    'settings.chat': ['채팅', 'Chat', 'チャット', '聊天'],
    'settings.replay': ['그림 그리는 과정 재생', 'Replay drawing strokes', '描く過程を再生', '回放绘制过程'],
    'settings.replayDesc': ['완성본은 항상 보이고, 켜면 ▶ 버튼으로 그리는 과정을 재생할 수 있어요.', 'The finished drawing always shows; when on, tap ▶ to replay how it was drawn.', '完成した絵は常に表示され、オンにすると▶で描く過程を再生できます。', '始终显示完成的图画；开启后可点 ▶ 回放绘制过程。'],
    'settings.readReceipt': ['읽음 표시', 'Read Receipts', '既読表示', '已读回执'],
    'settings.readReceiptDesc': ['켠 사람끼리만 서로 읽음 표시가 보여요.', 'Only shown between people who both turned it on.', 'お互いにオンにした人同士だけ既読が表示されます。', '仅在双方都开启时互相显示已读。'],
    'settings.notif': ['알림', 'Notifications', '通知', '通知'],
    'settings.notifAll': ['알림 받기', 'Receive notifications', '通知を受け取る', '接收通知'],
    'settings.vibrate': ['진동', 'Vibration', 'バイブレーション', '振动'],
    'settings.sound': ['소리', 'Sound', 'サウンド', '声音'],
    'settings.notifNote': [
      '특정 방/사람 알림 끄기는 각 채팅방 오른쪽 위 종 아이콘에서 설정할 수 있어요.',
      'Mute a specific chat or person from the bell icon at the top of each chat.',
      '特定のチャット/相手のミュートは、各チャット右上のベルアイコンから設定できます。',
      '可在各聊天右上角的铃铛图标关闭指定聊天或联系人的提醒。'
    ],
    'settings.retention': ['메시지 보관', 'Message Retention', 'メッセージ保存', '消息保存'],
    'settings.disappearing': ['사라지는 메시지', 'Disappearing Messages', '消えるメッセージ', '消失的消息'],
    'settings.disappearingDesc': [
      '메시지는 어떤 경우에도 서버에 저장되지 않아요. 사라지는 메시지를 켜면 이 기기에서도 정한 시간 뒤 자동 삭제돼요.',
      'Messages are never stored on our servers. Turn this on to also auto-delete them from this device after a set time.',
      'メッセージはいかなる場合もサーバーに保存されません。オンにすると、この端末からも設定時間後に自動削除されます。',
      '消息在任何情况下都不会保存在服务器上。开启后，也会在设定时间后从本设备自动删除。'
    ],
    'retention.off': ['안 함 (계속 보관)', 'Off (keep)', 'しない（保存）', '关闭（保留）'],
    'retention.h24': ['24시간 후 삭제', 'After 24 hours', '24時間後に削除', '24小时后删除'],
    'retention.d7': ['7일 후 삭제', 'After 7 days', '7日後に削除', '7天后删除'],
    'settings.retentionDesc': [
      '메시지는 어떤 옵션에서도 서버에 저장되지 않아요. 위 설정은 내 기기에서 메시지를 언제 지울지만 정해요.',
      'Messages are never stored on our servers regardless of this option. It only controls when they are removed from your device.',
      'メッセージはどのオプションでもサーバーに保存されません。上の設定は端末から削除するタイミングだけを決めます。',
      '无论选择哪个选项，消息都不会保存在服务器上。以上设置仅决定何时从您的设备删除。'
    ],
    'settings.policies': ['약관 및 정책', 'Terms & Policies', '規約とポリシー', '条款与政策'],
    // 그림판
    'draw.title': ['그림 그리기', 'Draw', 'お絵かき', '画图'],
    // 지원 (공지/FAQ) + 관리자
    'support.section': ['지원', 'Support', 'サポート', '支持'],
    'support.announcements': ['공지사항', 'Announcements', 'お知らせ', '公告'],
    'support.faq': ['자주 묻는 질문', 'FAQ', 'よくある質問', '常见问题'],
    'support.empty': ['아직 등록된 글이 없어요.', 'Nothing here yet.', 'まだ投稿がありません。', '暂无内容。'],
    'support.write': ['글쓰기', 'Write', '投稿', '写文章'],
    'support.publish': ['등록', 'Publish', '公開', '发布'],
    'support.postTitle': ['제목', 'Title', 'タイトル', '标题'],
    'support.postBody': ['내용', 'Content', '内容', '内容'],
    'settings.appInfo': ['앱 정보', 'App Info', 'アプリ情報', '应用信息'],
    'admin.title': ['관리자 모드', 'Admin Mode', '管理者モード', '管理员模式'],
    'admin.password': ['관리자 비밀번호', 'Admin Password', '管理者パスワード', '管理员密码'],
    'admin.unlocked': ['관리자 모드가 켜졌어요.', 'Admin mode enabled.', '管理者モードが有効になりました。', '已启用管理员模式。'],
    'admin.wrong': ['비밀번호가 올바르지 않아요.', 'Incorrect password.', 'パスワードが正しくありません。', '密码不正确。'],
    'admin.active': ['관리자 모드 켜짐', 'Admin mode on', '管理者モード オン', '管理员模式已开'],
    'admin.console': ['관리자 콘솔', 'Admin Console', '管理コンソール', '管理控制台'],
    'admin.reports': ['신고 목록', 'Reports', '通報一覧', '举报列表'],
    'admin.suspensions': ['정지 목록', 'Suspensions', '停止一覧', '封禁列表'],
    'admin.noReports': ['접수된 신고가 없어요.', 'No reports.', '通報はありません。', '暂无举报。'],
    'admin.noSuspensions': ['정지된 사용자가 없어요.', 'No suspended users.', '停止中のユーザーはいません。', '暂无封禁用户。'],
    'admin.reported': ['신고 대상', 'Reported', '対象', '被举报者'],
    'admin.suspend': ['정지', 'Suspend', '停止', '封禁'],
    'admin.suspendTitle': ['사용자 정지', 'Suspend User', 'ユーザーを停止', '封禁用户'],
    'admin.suspendReason': ['정지 사유 (필수)', 'Reason (required)', '停止理由（必須）', '封禁原因（必填）'],
    'admin.suspended': ['정지되었어요.', 'User suspended.', '停止しました。', '已封禁。'],
    'admin.unsuspend': ['해제', 'Unsuspend', '解除', '解封'],
    'admin.openConsole': ['관리자 콘솔', 'Admin Console', '管理コンソール', '管理控制台'],
    'error.suspendReasonRequired': ['정지 사유를 입력해 주세요.', 'Please enter a reason.', '停止理由を入力してください。', '请输入封禁原因。'],
    // 친구 차단/삭제 관리
    'friend.block': ['차단', 'Block', 'ブロック', '拉黑'],
    'friend.hide': ['삭제', 'Delete', '削除', '删除'],
    'friend.restore': ['복원', 'Restore', '復元', '恢复'],
    'friend.manage': ['차단·삭제 친구 관리', 'Blocked & Deleted Friends', 'ブロック・削除した友だち', '拉黑与已删除的朋友'],
    'friend.blockedSection': ['차단한 친구', 'Blocked', 'ブロック中', '已拉黑'],
    'friend.hiddenSection': ['삭제한 친구', 'Deleted', '削除済み', '已删除'],
    'friend.manageEmpty': ['차단하거나 삭제한 친구가 없어요.', 'No blocked or deleted friends.', 'ブロック・削除した友だちはいません。', '没有拉黑或删除的朋友。'],
    // 신고
    'report': ['신고', 'Report', '通報', '举报'],
    'report.title': ['무엇이 문제인가요?', 'What\'s wrong?', '何が問題ですか？', '有什么问题？'],
    'report.spam': ['스팸/광고', 'Spam or ads', 'スパム/広告', '垃圾信息/广告'],
    'report.harassment': ['괴롭힘/욕설', 'Harassment', '嫌がらせ/暴言', '骚扰/辱骂'],
    'report.sexual': ['음란물', 'Sexual content', 'わいせつ物', '色情内容'],
    'report.illegal': ['불법 정보', 'Illegal content', '違法情報', '违法信息'],
    'report.other': ['기타', 'Other', 'その他', '其他'],
    'report.done': ['신고가 접수되었어요. 검토 후 조치할게요.', 'Report received. We\'ll review it.', '通報を受け付けました。確認いたします。', '举报已收到，我们会进行审核。'],
    'report.alsoBlock': ['이 사용자를 차단할까요?', 'Block this user too?', 'このユーザーをブロックしますか？', '同时拉黑该用户？'],
    // 꾹 누르기 메뉴
    'menu.copy': ['복사', 'Copy', 'コピー', '复制'],
    'menu.forward': ['전달', 'Forward', '転送', '转发'],
    'menu.share': ['공유', 'Share', '共有', '分享'],
    'copied': ['복사했어요', 'Copied', 'コピーしました', '已复制'],
    'forward.title': ['전달할 대화 선택', 'Forward to', '転送先を選択', '选择转发对象'],
    // 네트워크
    'net.offline': ['인터넷 연결이 없어요', 'No internet connection', 'インターネット接続がありません', '无网络连接'],
    'net.errorTitle': ['불러오지 못했어요', 'Couldn\'t load', '読み込めませんでした', '加载失败'],
    'net.errorDesc': ['네트워크 상태를 확인해 주세요.', 'Please check your connection.', 'ネットワーク状態を確認してください。', '请检查网络连接。'],
    'net.retry': ['다시 시도', 'Retry', '再試行', '重试'],
    // 번역
    'translate': ['번역', 'Translate', '翻訳', '翻译'],
    'translate.original': ['원문 보기', 'Show Original', '原文を表示', '查看原文'],
    'translate.badge': ['번역됨', 'Translated', '翻訳済み', '已翻译'],
    'translate.failed': ['번역에 실패했어요', 'Translation failed', '翻訳に失敗しました', '翻译失败'],
    // UseCase 검증 에러 (키로 throw됨)
    'error.nicknameRequired': ['닉네임을 입력해 주세요.', 'Please enter a nickname.', 'ニックネームを入力してください。', '请输入昵称。'],
    'error.groupMinMembers': ['단톡방은 3명 이상부터 만들 수 있어요.', 'Group chats need at least 3 members.', 'グループチャットは3人以上から作成できます。', '群聊至少需要3人。'],
    'error.emptyMessage': ['빈 메시지는 보낼 수 없어요.', "Can't send an empty message.", '空のメッセージは送信できません。', '不能发送空消息。'],
    'error.emoticonNameRequired': ['이모티콘 이름을 입력해 주세요.', 'Please name your emoticon.', 'スタンプの名前を入力してください。', '请为表情命名。'],
    'error.drawingRequired': ['그림을 먼저 그려주세요.', 'Please draw something first.', 'まず絵を描いてください。', '请先画点什么。'],
    'error.priceNegative': ['가격은 0 이상이어야 해요.', 'Price must be 0 or more.', '価格は0以上にしてください。', '价格必须大于等于0。'],
    'error.sendFailed': ['메시지 전송에 실패했어요. 다시 시도해 주세요.', 'Failed to send. Please try again.', '送信に失敗しました。もう一度お試しください。', '发送失败，请重试。'],
    'feature not available yet': ['아직 준비 중인 기능이에요.', "This feature isn't available yet.", 'この機能はまだ準備中です。', '该功能尚未开放。'],
  };
}
