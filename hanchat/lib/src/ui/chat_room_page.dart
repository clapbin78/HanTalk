import 'dart:async';

import 'package:flutter/material.dart';

import '../core/entities.dart';
import '../data/client.dart';
import 'drawing.dart';
import 'l10n.dart';
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

  ChatRoomViewModel(this._client, this.room);

  bool get aiEnabled => _client.config.aiAssistantEnabled;

  void start() {
    _subscription ??= _client.observeMessages(room.id).listen((value) {
      messages = value;
      notifyListeners();
    });
    _client.getCurrentUser().then((me) {
      myId = me?.id;
      notifyListeners();
    });
    _client.getFriends().then((value) {
      friends = value;
      notifyListeners();
    });
    if (aiEnabled) _loadAISuggestions();
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

  @override
  void dispose() {
    _vm.dispose();
    _input.dispose();
    _scroll.dispose();
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
            title: Text(widget.room.kind == RoomKind.group
                ? (widget.room.name ?? l10n.t('chats.group'))
                : ''),
          ),
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(l10n.t('room.retention'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _vm.messages.length,
                  itemBuilder: (context, index) {
                    final message = _vm.messages[index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == _vm.myId,
                      senderName: widget.room.kind == RoomKind.group &&
                              message.senderId != _vm.myId
                          ? _vm.senderName(message, l10n)
                          : null,
                    );
                  },
                ),
              ),
              _inputBar(l10n),
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
            icon: const Icon(Icons.brush),
            onPressed: () async {
              final payload = await Navigator.of(context).push<DrawingPayload>(
                MaterialPageRoute(
                    builder: (_) => const DrawingCanvasPage(), fullscreenDialog: true),
              );
              if (payload != null) await _vm.sendDrawing(payload);
            },
          ),
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined),
            onPressed: _showEmoticonPicker,
          ),
          Expanded(
            child: TextField(
              controller: _input,
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
            onPressed: _input.text.trim().isEmpty
                ? null
                : () {
                    final text = _input.text;
                    _input.clear();
                    _vm.sendText(text);
                  },
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

  void _maybeShowError(HanChatL10n l10n) {
    final key = _vm.errorKey;
    if (key == null) return;
    _vm.errorKey = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t(key))));
    });
  }

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

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
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
          child: TranslatableText(text,
              style: const TextStyle(color: Colors.black87)),
        ),
      DrawingContent(payload: final payload) => Container(
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
      EmoticonContent(payload: final payload) =>
        SizedBox(width: 140, height: 140, child: DrawingReplayView(payload)),
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
        Text(TimeOfDay.fromDateTime(message.sentAt).format(context),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
}
