import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/entities.dart';
import '../data/client.dart';
import '../data/notification_setting.dart';
import '../data/read_receipt_setting.dart';
import '../data/retention_setting.dart';
import '../core/report.dart';
import 'drawing.dart';
import 'l10n.dart';
import 'profile_view_page.dart';
import 'report_sheet.dart';
import 'theme.dart';
import 'translatable_text.dart';

class ChatRoomViewModel extends ChangeNotifier {
  final HanChatClient _client;
  final ChatRoom room;
  StreamSubscription<List<Message>>? _subscription;

  List<Message> messages = [];
  List<Friend> friends = [];
  List<Emoticon> myEmoticons = [];
  List<String> aiSuggestions = []; // 🚩 aiAssistantEnabled 켜져야 UI 노출
  String? myId;
  String? errorKey;
  bool readReceiptsOn = false; // 내 읽음표시 설정 (표시 게이트)
  bool muted = false; // 이 방 알림 음소거
  String retentionOption = RetentionSetting.optionOff; // 사라지는 메시지 상태

  ChatRoomViewModel(this._client, this.room);

  /// 상단 안내 배너 문구 키 — 보관 설정에 따라 다름
  String get retentionBannerKey => switch (retentionOption) {
        RetentionSetting.option24h => 'room.retention', // 24시간
        RetentionSetting.option7d => 'room.disappear7d',
        _ => 'room.serverOnly', // 계속 보관(기본) — 서버엔 안 남음만 안내
      };

  bool get aiEnabled => _client.config.aiAssistantEnabled;

  void start() {
    _subscription ??= _client.observeMessages(room.id).listen((value) {
      messages = value;
      notifyListeners();
      _markRead(); // 새 메시지 도착 시에도 읽음 신호
    });
    _client.getCurrentUser().then((me) {
      myId = me?.id;
      notifyListeners();
      _markRead();
    });
    _client.getFriends().then((value) {
      friends = value;
      notifyListeners();
    });
    ReadReceiptSetting.isEnabled().then((on) {
      readReceiptsOn = on;
      notifyListeners();
    });
    NotificationSetting.isRoomMuted(room.id).then((m) {
      muted = m;
      notifyListeners();
    });
    RetentionSetting.currentOption(_client.config.localRetention).then((opt) {
      retentionOption = opt;
      notifyListeners();
    });
    if (aiEnabled) _loadAISuggestions();
  }

  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
    await NotificationSetting.setRoomMuted(room.id, muted);
  }

  Future<void> _markRead() async {
    final id = myId;
    if (id == null || messages.isEmpty) return;
    final on = await ReadReceiptSetting.isEnabled();
    await _client.markRoomRead(
        roomId: room.id, messages: messages, myId: id, enabled: on);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> sendText(String text) => _send(TextContent(text));

  Future<void> sendDrawing(DrawingPayload payload) => _send(DrawingContent(payload));

  Future<void> sendEmoticon(Emoticon emoticon) => _send(
      EmoticonContent(emoticonId: emoticon.id, payload: emoticon.payload));

  Future<void> _send(MessageContent content) async {
    try {
      await _client.sendMessage(content, roomId: room.id);
    } catch (e) {
      errorKey = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadMyEmoticons() async {
    myEmoticons = await _client.getMyEmoticons();
    notifyListeners();
  }

  /// 전달 대상 방 목록 (현재 방 제외)
  Future<List<ChatRoom>> forwardTargets() async {
    final all = await _client.observeRooms().first;
    return [for (final r in all) if (r.id != room.id) r];
  }

  Future<void> forwardTo(String targetRoomId, MessageContent content) async {
    try {
      await _client.sendMessage(content, roomId: targetRoomId);
    } catch (e) {
      errorKey = e.toString();
      notifyListeners();
    }
  }

  String roomTitle(ChatRoom target, HanChatL10n l10n) {
    if (target.kind == RoomKind.group) return target.name ?? l10n.t('chats.group');
    final otherId = target.memberIds.where((id) => id != myId).firstOrNull;
    for (final f in friends) {
      if (f.id == otherId) return f.displayName;
    }
    return l10n.t('unknown');
  }

  Future<void> _loadAISuggestions() async {
    try {
      aiSuggestions = await _client.suggestReplies(
        context: messages,
        languageCode: 'ko',
      );
      notifyListeners();
    } catch (_) {}
  }

  String senderName(Message message, HanChatL10n l10n) {
    for (final f in friends) {
      if (f.id == message.senderId) return f.displayName;
    }
    return l10n.t('unknown');
  }

  /// 1:1 상대 id (그룹이면 null)
  String? get otherMemberId {
    if (room.kind != RoomKind.direct) return null;
    return room.memberIds.where((id) => id != myId).firstOrNull;
  }

  String directTitle(HanChatL10n l10n) {
    final id = otherMemberId;
    for (final f in friends) {
      if (f.id == id) return f.displayName;
    }
    return l10n.t('unknown');
  }
}

class ChatRoomPage extends StatefulWidget {
  final ChatRoom room;
  const ChatRoomPage({super.key, required this.room});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late final _vm = ChatRoomViewModel(HanChat.client, widget.room)..start();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  final _drawingController = MiniDrawingController();
  bool _showCanvas = false; // 인라인 그림판 (키보드 자리)

  @override
  void initState() {
    super.initState();
    // 입력창에 포커스 오면(키보드 올라오면) 그림판은 접는다
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _showCanvas) {
        setState(() => _showCanvas = false);
      }
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);

    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        _maybeShowError(l10n);
        _scrollToBottomSoon();
        return Scaffold(
          appBar: AppBar(
            // 1:1은 상대 이름 표시 + 탭하면 상대 프로필. 그룹은 방 이름.
            title: widget.room.kind == RoomKind.group
                ? Text(widget.room.name ?? l10n.t('chats.group'))
                : GestureDetector(
                    onTap: () {
                      final id = _vm.otherMemberId;
                      if (id != null) {
                        openProfile(context,
                            userId: id, fallbackName: _vm.directTitle(l10n));
                      }
                    },
                    child: Text(_vm.directTitle(l10n)),
                  ),
            actions: [
              // 이 방 알림 끄기/켜기 (특정인 음소거 = 그 사람과의 1:1 방 음소거)
              IconButton(
                icon: Icon(_vm.muted
                    ? Icons.notifications_off
                    : Icons.notifications_none),
                tooltip: l10n.t(_vm.muted ? 'room.unmute' : 'room.mute'),
                onPressed: () {
                  _vm.toggleMute();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.t(_vm.muted ? 'room.muted' : 'room.unmuted')),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ));
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(l10n.t(_vm.retentionBannerKey),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
              Expanded(
                // 바탕 아무데나 탭 → 키보드/그림판 내리기
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (_showCanvas) setState(() => _showCanvas = false);
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag, // 스크롤로도 내려감
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _vm.messages.length,
                    itemBuilder: (context, index) {
                      final message = _vm.messages[index];
                      // 같은 사람이 같은 '분'에 연속으로 보낸 메시지는
                      // 마지막 버블에만 시간 표시 (시간 표시 겹침 제거)
                      final next = index + 1 < _vm.messages.length
                          ? _vm.messages[index + 1]
                          : null;
                      final showTime = next == null ||
                          next.senderId != message.senderId ||
                          !_sameMinute(next.sentAt, message.sentAt);
                      return _MessageBubble(
                        message: message,
                        isMine: message.senderId == _vm.myId,
                        senderName: widget.room.kind == RoomKind.group &&
                                message.senderId != _vm.myId
                            ? _vm.senderName(message, l10n)
                            : null,
                        onForward: _forward,
                        isGroup: widget.room.kind == RoomKind.group,
                        showReadMark: _vm.readReceiptsOn,
                        showTime: showTime,
                      );
                    },
                  ),
                ),
              ),
              _inputBar(l10n),
              // 인라인 미니 그림판 — 키보드 자리처럼 입력창 아래에서 펼쳐짐 (화면 절반까지)
              // 보내기 버튼은 입력바에 하나만 (그림판 열려있으면 그림을 보냄)
              if (_showCanvas)
                SizedBox(
                  height: (MediaQuery.of(context).size.height * 0.45)
                      .clamp(220.0, 420.0),
                  child: MiniDrawingPanel(controller: _drawingController),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _inputBar(HanChatL10n l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 🚩 AI 답장 추천 칩 — 플래그 꺼져 있으면 렌더링 자체가 안 됨
        if (_vm.aiEnabled && _vm.aiSuggestions.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final suggestion in _vm.aiSuggestions)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _input.text = suggestion,
                  ),
                ),
            ]),
          ),
        Row(children: [
          IconButton(
            icon: Icon(_showCanvas ? Icons.keyboard : Icons.brush),
            onPressed: () {
              // 키보드 ↔ 그림판 전환 (키보드는 내려가고 그 자리에 그림판)
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => _showCanvas = !_showCanvas);
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: _showEmoticonPicker,
          ),
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _inputFocus,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.t('room.input'),
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_circle_up, size: 30),
            // 그림판이 열려 있으면 그림 전송, 아니면 텍스트 전송
            onPressed: (_showCanvas || _input.text.trim().isNotEmpty)
                ? () {
                    if (_showCanvas) {
                      final payload = _drawingController.take();
                      if (payload != null) _vm.sendDrawing(payload);
                      setState(() => _showCanvas = false);
                      return;
                    }
                    final text = _input.text;
                    _input.clear();
                    _vm.sendText(text);
                  }
                : null,
          ),
        ]),
      ]),
    );
  }

  void _showEmoticonPicker() {
    _vm.loadMyEmoticons();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final l10n = HanChatL10n.of(context);
        return ListenableBuilder(
          listenable: _vm,
          builder: (context, _) => SafeArea(
            child: SizedBox(
              height: 280,
              child: _vm.myEmoticons.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.t('room.emptyCollection'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(l10n.t('room.emptyCollectionDesc'),
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]))
                  : GridView.count(
                      crossAxisCount: 4,
                      padding: const EdgeInsets.all(12),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final emoticon in _vm.myEmoticons)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _vm.sendEmoticon(emoticon);
                            },
                            child: Column(children: [
                              Expanded(child: DrawingThumbnail(emoticon.payload)),
                              Text(emoticon.name,
                                  style: const TextStyle(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  /// 전달: 방 선택 시트 → 선택한 방으로 같은 내용 전송
  Future<void> _forward(MessageContent content) async {
    final targets = await _vm.forwardTargets();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final l10n = HanChatL10n.of(sheetContext);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(l10n.t('forward.title'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final target in targets)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Text(_vm.roomTitle(target, l10n).characters.first,
                          style: const TextStyle(color: Colors.black54)),
                    ),
                    title: Text(_vm.roomTitle(target, l10n)),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _vm.forwardTo(target.id, content);
                    },
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  void _maybeShowError(HanChatL10n l10n) {
    final key = _vm.errorKey;
    if (key == null) return;
    _vm.errorKey = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // floating: 입력창을 가리지 않게 띄움
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t(key)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    });
  }

  bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final String? senderName;
  final void Function(MessageContent) onForward;
  final bool isGroup;
  final bool showReadMark; // 내 읽음표시 설정이 켜졌을 때만
  final bool showTime; // 같은 분 연속 메시지는 마지막에만 시간

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    required this.onForward,
    this.isGroup = false,
    this.showReadMark = false,
    this.showTime = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    final theme = HanChatTheme.of(context);

    final bubble = switch (message.content) {
      TextContent(text: final text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMine ? theme.myBubble : theme.otherBubble,
            borderRadius: BorderRadius.circular(16),
          ),
          // 꾹 누르면: 번역 · 복사 · 전달 · 공유
          child: TranslatableText(
            text,
            style: const TextStyle(color: Colors.black87),
            extraActions: [
              TextMenuAction(
                icon: Icons.copy,
                label: l10n.t('menu.copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                    content: Text(l10n.t('copied')),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ));
                },
              ),
              TextMenuAction(
                icon: Icons.reply,
                label: l10n.t('menu.forward'),
                onTap: () => onForward(message.content),
              ),
              TextMenuAction(
                icon: Icons.ios_share,
                label: l10n.t('menu.share'),
                onTap: () => Share.share(text),
              ),
              // 남의 메시지만 신고 가능
              if (!isMine)
                TextMenuAction(
                  icon: Icons.flag_outlined,
                  label: l10n.t('report'),
                  onTap: () => showReportSheet(
                    context,
                    targetType: ReportTargetType.message,
                    targetId: message.id,
                    reportedUserId: message.senderId,
                    snapshot: text,
                  ),
                ),
            ],
          ),
        ),
      DrawingContent(payload: final payload) => _forwardable(
          l10n,
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: DrawingReplayView(payload),
          ),
        ),
      EmoticonContent(payload: final payload) => _forwardable(
          l10n,
          SizedBox(width: 140, height: 140, child: DrawingReplayView(payload)),
        ),
      // 제어 메시지(읽음 신호)는 화면에 표시되지 않음 (여기 도달할 일 없음)
      ReadReceiptContent() => const SizedBox.shrink(),
    };

    final meta = Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isMine && message.deliveryState == DeliveryState.sending)
          Text(l10n.t('room.sending'),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        if (isMine && message.deliveryState == DeliveryState.failed)
          Text(l10n.t('room.failed'),
              style: const TextStyle(fontSize: 10, color: Colors.red)),
        // 읽음표시 — 보낼 땐 표시 없음. 읽으면:
        //   1:1 = 체크 1개, 단톡 = 읽은 사람 수 (내 설정이 켜진 경우에만)
        if (isMine && showReadMark && message.readCount > 0)
          isGroup
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.done, size: 13, color: Colors.green.shade600),
                  const SizedBox(width: 2),
                  Text('${message.readCount}',
                      style:
                          TextStyle(fontSize: 10, color: Colors.green.shade600)),
                ])
              : Icon(Icons.done, size: 14, color: Colors.green.shade600),
        if (showTime)
          Text(TimeOfDay.fromDateTime(message.sentAt).format(context),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        // (아래는 기존 레이아웃 그대로)
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMine) ...[meta, const SizedBox(width: 6)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(senderName!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ),
                bubble,
              ],
            ),
          ),
          if (!isMine) ...[const SizedBox(width: 6), meta],
        ],
      ),
    );
  }

  /// 그림/이모티콘 말풍선: 꾹 누르면 전달 메뉴
  Widget _forwardable(HanChatL10n l10n, Widget child) {
    return Builder(builder: (context) {
      return GestureDetector(
        onLongPressStart: (details) async {
          final position = details.globalPosition;
          final action = await showMenu<String>(
            context: context,
            position:
                RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
            items: [
              PopupMenuItem(
                value: 'forward',
                child: Row(children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.t('menu.forward')),
                ]),
              ),
            ],
          );
          if (action == 'forward') onForward(message.content);
        },
        child: child,
      );
    });
  }
}
