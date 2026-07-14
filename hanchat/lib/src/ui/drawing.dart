import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide colorFromHex;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/entities.dart';
import 'l10n.dart';
import 'theme.dart';

// ── 그림 렌더링 (정지) ─────────────────────────────────────

class DrawingPainter extends CustomPainter {
  final DrawingPayload payload;

  /// 재생 중이면 이 시각(초)까지 그려진 점만 표시. null = 완성본.
  final double? elapsed;

  DrawingPainter(this.payload, {this.elapsed});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = _min(size.width / _max(payload.canvasWidth, 1),
        size.height / _max(payload.canvasHeight, 1));

    for (final stroke in payload.strokes) {
      final visible = elapsed == null
          ? stroke.points
          : [for (final p in stroke.points) if (p.t <= elapsed!) p];
      if (visible.isEmpty) continue;

      final paint = Paint()
        ..color = colorFromHex(stroke.colorHex)
        ..strokeWidth = stroke.width * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (visible.length == 1) {
        canvas.drawCircle(
          Offset(visible.first.x * scale, visible.first.y * scale),
          stroke.width * scale / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()..moveTo(visible.first.x * scale, visible.first.y * scale);
      for (final p in visible.skip(1)) {
        path.lineTo(p.x * scale, p.y * scale);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) =>
      oldDelegate.payload != payload || oldDelegate.elapsed != elapsed;
}

/// 갤러리 목록용 정지 썸네일.
class DrawingThumbnail extends StatelessWidget {
  final DrawingPayload payload;
  const DrawingThumbnail(this.payload, {super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: DrawingPainter(payload));
}

// ── 그리는 과정 재생 ───────────────────────────────────────

/// 설정 토글 (기본 켜짐). 끄면 완성본만 바로 표시.
class DrawingReplaySetting {
  static const _key = 'hanchat.drawingReplayEnabled';

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? true;

  static Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}

/// 그림/이모티콘 메시지 표시 + 그리는 과정 재생.
/// 점에 기록된 타임스탬프(t)만으로 수신 기기에서 로컬 재생 — 서버 비용 0.
class DrawingReplayView extends StatefulWidget {
  final DrawingPayload payload;
  const DrawingReplayView(this.payload, {super.key});

  @override
  State<DrawingReplayView> createState() => _DrawingReplayViewState();
}

class _DrawingReplayViewState extends State<DrawingReplayView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _replayEnabled = true;

  double get _duration =>
      widget.payload.totalDuration <= 0 ? 0.001 : widget.payload.totalDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_duration * 1000).round()),
      value: 1, // 기본은 완성본
    );
    DrawingReplaySetting.isEnabled().then((enabled) {
      if (!mounted) return;
      setState(() => _replayEnabled = enabled);
      if (enabled) _controller.forward(from: 0); // 도착 직후 1회 자동 재생
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => CustomPaint(
            painter: DrawingPainter(
              widget.payload,
              elapsed: _controller.value >= 1 ? null : _controller.value * _duration,
            ),
          ),
        ),
      ),
      if (_replayEnabled)
        Positioned(
          right: 2,
          bottom: 2,
          child: IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 22, color: Colors.grey),
            onPressed: () => _controller.forward(from: 0),
            visualDensity: VisualDensity.compact,
          ),
        ),
    ]);
  }
}

// ── 미니 그림판 (펜 색상 + 두께만) ──────────────────────────
//
// 채팅방에서는 키보드 자리처럼 입력창 아래에서 펼쳐진다 (화면 절반까지).
// 이모티콘 업로드 플로우는 같은 패널을 전체 화면으로 감싸서 재사용.

/// 부모(채팅 입력바)가 그림판의 현재 그림을 꺼낼 수 있게 하는 컨트롤러.
/// 보내기 버튼을 그림판이 아니라 입력바에 하나만 두기 위한 다리.
class MiniDrawingController {
  DrawingPayload? Function()? _take;

  /// 현재 그림을 payload로 꺼내고 캔버스를 비운다. 그림 없으면 null.
  DrawingPayload? take() => _take?.call();
}

class MiniDrawingPanel extends StatefulWidget {
  final MiniDrawingController controller;
  const MiniDrawingPanel({super.key, required this.controller});

  @override
  State<MiniDrawingPanel> createState() => _MiniDrawingPanelState();
}

class _MiniDrawingPanelState extends State<MiniDrawingPanel> {
  // 빠른 선택용 기본 스와치 + '+' 로 색상환
  static const _palette = [
    '#1C1C1E', '#FF3B30', '#FF9500', '#FFCC00', '#34C759', '#007AFF', '#AF52DE',
  ];

  final _strokes = <Stroke>[];
  var _currentPoints = <StrokePoint>[];
  DateTime? _startedAt;
  String _colorHex = '#1C1C1E';
  double _penWidth = 4;
  Size _canvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller._take = _take;
  }

  DrawingPayload? _take() {
    _endStroke();
    if (_strokes.isEmpty) return null;
    final payload = _currentPayload();
    setState(() {
      _strokes.clear();
      _currentPoints = [];
      _startedAt = null;
    });
    return payload;
  }

  @override
  Widget build(BuildContext context) {
    final theme = HanChatTheme.of(context);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(children: [
        // 1줄: 색상 스와치들 + 색상환(+) + undo
        Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final hex in _palette) ...[
                  _swatch(hex, theme),
                  const SizedBox(width: 6),
                ],
                // 색상환 버튼 (현재 색 표시 + 탭하면 피커)
                GestureDetector(
                  onTap: _openColorPicker,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const SweepGradient(colors: [
                        Colors.red, Colors.yellow, Colors.green,
                        Colors.cyan, Colors.blue, Colors.purple, Colors.red,
                      ]),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.removeLast()),
          ),
        ]),
        // 2줄: 펜 두께
        Row(children: [
          const Icon(Icons.line_weight, size: 18),
          Expanded(
            child: Slider(
              value: _penWidth,
              min: 1,
              max: 20,
              activeColor: theme.accent,
              onChanged: (v) => setState(() => _penWidth = v),
            ),
          ),
          Container(
            width: 26,
            alignment: Alignment.center,
            child: Container(
              width: _penWidth.clamp(4, 22),
              height: _penWidth.clamp(4, 22),
              decoration: BoxDecoration(
                color: colorFromHex(_colorHex),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            _canvasSize = constraints.biggest;
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onPanStart: (d) => _addPoint(d.localPosition),
                onPanUpdate: (d) => _addPoint(d.localPosition),
                onPanEnd: (_) => _endStroke(),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DrawingPainter(_currentPayload()),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _swatch(String hex, HanChatTheme theme) => GestureDetector(
        onTap: () => setState(() => _colorHex = hex),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colorFromHex(hex),
            shape: BoxShape.circle,
            border: hex == _colorHex
                ? Border.all(color: theme.accent, width: 2.5)
                : Border.all(color: Colors.grey.shade300),
          ),
        ),
      );

  Future<void> _openColorPicker() async {
    final l10n = HanChatL10n.of(context);
    var picked = colorFromHex(_colorHex);
    final result = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel'))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(picked),
              child: Text(l10n.t('ok'))),
        ],
      ),
    );
    if (result != null) {
      final hex = '#${(result.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      setState(() => _colorHex = hex);
    }
  }

  DrawingPayload _currentPayload() => DrawingPayload(
        canvasWidth: _max(_canvasSize.width, 1),
        canvasHeight: _max(_canvasSize.height, 1),
        strokes: [
          ..._strokes,
          if (_currentPoints.isNotEmpty)
            Stroke(colorHex: _colorHex, width: _penWidth, points: _currentPoints),
        ],
      );

  void _addPoint(Offset position) {
    _startedAt ??= DateTime.now();
    final t = DateTime.now().difference(_startedAt!).inMilliseconds / 1000.0;
    setState(() {
      _currentPoints = [
        ..._currentPoints,
        StrokePoint(x: position.dx, y: position.dy, t: t),
      ];
    });
  }

  void _endStroke() {
    if (_currentPoints.isEmpty) return;
    _strokes.add(
        Stroke(colorHex: _colorHex, width: _penWidth, points: _currentPoints));
    _currentPoints = [];
    if (mounted) setState(() {});
  }
}

/// 전체 화면 그림판 — 이모티콘 업로드 플로우용. 확정 버튼은 앱바 우상단.
class DrawingCanvasPage extends StatefulWidget {
  final String confirmLabelKey;
  const DrawingCanvasPage({super.key, this.confirmLabelKey = 'send'});

  @override
  State<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

class _DrawingCanvasPageState extends State<DrawingCanvasPage> {
  final _controller = MiniDrawingController();

  @override
  Widget build(BuildContext context) {
    final l10n = HanChatL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('draw.title')),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('cancel')),
        ),
        leadingWidth: 80,
        actions: [
          TextButton(
            onPressed: () {
              final payload = _controller.take();
              if (payload != null) Navigator.of(context).pop(payload);
            },
            child: Text(l10n.t(widget.confirmLabelKey),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(child: MiniDrawingPanel(controller: _controller)),
    );
  }
}

double _max(double a, double b) => a > b ? a : b;
double _min(double a, double b) => a < b ? a : b;
