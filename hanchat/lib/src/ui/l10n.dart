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
      '메시지는 서버에 남지 않고,\n기기에서도 24시간 뒤 사라져요.',
      'Messages never stay on our servers,\nand disappear from your device after 24 hours.',
      'メッセージはサーバーに残らず、\n端末からも24時間後に消えます。',
      '消息不会保存在服务器上，\n24小时后也会从设备中消失。'
    ],
    'onboard.agreeTerms': ['이용약관 동의 (필수)', 'Agree to Terms of Service (required)', '利用規約に同意（必須）', '同意服务条款（必填）'],
    'onboard.agreePrivacy': ['개인정보 수집·이용 동의 (필수)', 'Agree to Privacy Policy (required)', '個人情報の取扱いに同意（必須）', '同意隐私政策（必填）'],
    'onboard.view': ['보기', 'View', '見る', '查看'],
    'onboard.start': ['동의하고 시작하기', 'Agree & Start', '同意して始める', '同意并开始'],
    'terms': ['이용약관', 'Terms of Service', '利用規約', '服务条款'],
    'privacy': ['개인정보처리방침', 'Privacy Policy', 'プライバシーポリシー', '隐私政策'],
    'profile': ['프로필', 'Profile', 'プロフィール', '个人资料'],
    'profile.create': ['프로필 만들기', 'Create Profile', 'プロフィール作成', '创建个人资料'],
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
    'room.input': ['메시지 입력', 'Message', 'メッセージを入力', '输入消息'],
    'room.sending': ['전송 중', 'Sending', '送信中', '发送中'],
    'room.failed': ['실패', 'Failed', '失敗', '失败'],
    'room.myEmoticons': ['내 이모티콘', 'My Emoticons', 'マイスタンプ', '我的表情'],
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
    'settings.replayDesc': ['끄면 완성된 그림만 바로 표시돼요.', 'When off, finished drawings appear instantly.', 'オフにすると完成した絵だけが表示されます。', '关闭后将直接显示完成的图画。'],
    'settings.retention': ['메시지 보관', 'Message Retention', 'メッセージ保存', '消息保存'],
    'settings.autoDelete': ['자동 삭제', 'Auto-delete', '自動削除', '自动删除'],
    'settings.never': ['안 함', 'Never', 'しない', '从不'],
    'settings.afterHours': ['%d시간 후', 'After %d hours', '%d時間後', '%d小时后'],
    'settings.retentionDesc': [
      '메시지는 서버에 저장되지 않으며, 이 기기에서도 위 기간이 지나면 자동으로 삭제됩니다.',
      'Messages are never stored on servers and are deleted from this device after the period above.',
      'メッセージはサーバーに保存されず、この端末からも上記の期間後に自動削除されます。',
      '消息不会存储在服务器上，超过上述期限后也会从本设备自动删除。'
    ],
    'settings.policies': ['약관 및 정책', 'Terms & Policies', '規約とポリシー', '条款与政策'],
    // 그림판
    'draw.title': ['그림 그리기', 'Draw', 'お絵かき', '画图'],
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
