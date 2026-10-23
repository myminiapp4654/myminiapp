import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../ui/kit.dart';
import 'maze_game.dart';

const _playerColor = Color(0xFFFFC233);
const _aiColor = Color(0xFF4CFF7A);

enum _Stage { ready, countdown, playing, won, lost }

/// Labirint musobaqasi: siz surib yurasiz, kompyuter yo'l qidiradi.
class MazeScreen extends StatefulWidget {
  /// 1 — oson (25×25), 2 — o'rta (29×29), 3 — qiyin (33×33)
  final int level;

  /// Testlar uchun
  final int? seed;
  final Maze? initialMaze;

  const MazeScreen({super.key, this.level = 2, this.seed, this.initialMaze});

  @override
  State<MazeScreen> createState() => _MazeScreenState();
}

class _MazeScreenState extends State<MazeScreen> with TickerProviderStateMixin {
  late final Random _rnd = Random(widget.seed);
  late Maze _maze =
      widget.initialMaze ?? Maze.generate(Maze.roomsFor(widget.level), _rnd);
  late MazeWalker _me = MazeWalker(_maze);
  late MazeRunner _ai = MazeRunner(_maze, widget.level, _rnd);

  _Stage _stage = _Stage.ready;
  int _count = 3;
  int _epoch = 0;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _aiDebt = 0;
  final _clock = Stopwatch();

  /// O'yinchi yurishi: navbatdagi kataklar va joriy katakdan keyingisigacha qism.
  final _queue = <int>[];
  double _moveT = 0;
  static const _cellsPerSecond = 16.0;

  /// Yurish paytida surilgan yo'nalish — to'xtagach bajariladi.
  (int, int)? _pending;

  /// Surishni aniqlash: bitta barmoq harakatida bir necha marta burish mumkin.
  Offset _swipe = Offset.zero;
  (int, int)? _swipeDir;

  /// Devorga qarab surildi — qisqa silkinish.
  late final AnimationController _bump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _epoch++;
    _ticker.dispose();
    _bump.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- bosqichlar

  Future<void> _start() async {
    final epoch = _epoch;
    setState(() {
      _stage = _Stage.countdown;
      _count = 3;
    });
    for (var k = 3; k >= 1; k--) {
      if (!mounted || epoch != _epoch) return;
      setState(() => _count = k);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted || epoch != _epoch) return;
    setState(() => _stage = _Stage.playing);
    HapticFeedback.mediumImpact();
    _clock
      ..reset()
      ..start();
    _last = Duration.zero;
    _aiDebt = 0;
    _ticker.start();
  }

  void _restart() {
    _epoch++;
    _ticker.stop();
    _clock
      ..stop()
      ..reset();
    setState(() {
      _maze = Maze.generate(Maze.roomsFor(widget.level), _rnd);
      _me = MazeWalker(_maze);
      _ai = MazeRunner(_maze, widget.level, _rnd);
      _queue.clear();
      _pending = null;
      _moveT = 0;
    });
    _start();
  }

  void _finish(bool won) {
    _ticker.stop();
    _clock.stop();
    _queue.clear();
    HapticFeedback.heavyImpact();
    setState(() => _stage = won ? _Stage.won : _Stage.lost);
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_stage != _Stage.playing) return;
    // O'yinchi katakma-katak silliq yuradi
    if (_queue.isNotEmpty) {
      _moveT += dt.clamp(0, 0.1) * _cellsPerSecond;
      while (_moveT >= 1 && _queue.isNotEmpty) {
        _moveT -= 1;
        _me.step(_queue.removeAt(0));
      }
      if (_me.finished) {
        _finish(true);
        return;
      }
      if (_queue.isEmpty) {
        _moveT = 0;
        HapticFeedback.selectionClick();
        final next = _pending;
        _pending = null;
        if (next != null) _go(next.$1, next.$2);
      }
    }
    _aiDebt += dt.clamp(0, 0.1) * _ai.speed;
    while (_aiDebt >= 1 && !_ai.finished) {
      _aiDebt -= 1;
      _ai.step();
    }
    if (_ai.finished) {
      _finish(false);
    } else {
      // Soat har kadrda yangilanadi
      setState(() {});
    }
  }

  // ---------------------------------------------------------------- boshqaruv

  /// Shu tomonga sirpanish (yurib turgan bo'lsa — to'xtagach).
  void _go(int dr, int dc) {
    if (_stage != _Stage.playing) return;
    if (_queue.isNotEmpty) {
      _pending = (dr, dc);
      return;
    }
    final path = _me.slide(dr, dc);
    if (path.isEmpty) {
      // Devor — o'yinchi biroz silkinadi
      HapticFeedback.lightImpact();
      _bump.forward(from: 0);
      return;
    }
    _queue.addAll(path);
    _moveT = 0;
  }

  void _panStart() {
    _swipe = Offset.zero;
    _swipeDir = null;
  }

  /// Barmoq yetarlicha surilganda yo'nalish aniqlanadi. Barmoqni ko'tarmay
  /// boshqa tomonga sursangiz — yana buriladi.
  void _panUpdate(Offset delta) {
    _swipe += delta;
    if (_swipe.distance < 18) return;
    final dir = _swipe.dx.abs() > _swipe.dy.abs()
        ? (0, _swipe.dx > 0 ? 1 : -1)
        : (_swipe.dy > 0 ? 1 : -1, 0);
    _swipe = Offset.zero;
    if (dir == _swipeDir) return;
    _swipeDir = dir;
    _go(dir.$1, dir.$2);
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final dir = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowUp => (-1, 0),
      LogicalKeyboardKey.arrowDown => (1, 0),
      LogicalKeyboardKey.arrowLeft => (0, -1),
      LogicalKeyboardKey.arrowRight => (0, 1),
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    _go(dir.$1, dir.$2);
    return KeyEventResult.handled;
  }

  /// O'yinchining ekrandagi joyi (katak birligida, harakat silliq).
  Offset get _pawn {
    Offset c(int i) => Offset(_maze.col(i) + 0.5, _maze.row(i) + 0.5);
    final from = c(_me.at);
    if (_queue.isEmpty) return from;
    return Offset.lerp(from, c(_queue.first), _moveT.clamp(0.0, 1.0))!;
  }

  // ---------------------------------------------------------------- ekran

  String get _time {
    final ms = _clock.elapsedMilliseconds;
    return '${ms ~/ 1000}.${(ms % 1000) ~/ 100} s';
  }

  @override
  Widget build(BuildContext context) {
    final size = _maze.size;
    return GameScaffold(
      title: 'Labirint',
      palette: GamePalette.maze,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _key,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Row(
                    children: [
                      const PlayerBadge(
                        color: _playerColor,
                        name: 'Siz',
                        active: true,
                        avatar: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _time,
                            key: const ValueKey('time'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const PlayerBadge(
                        color: _aiColor,
                        name: 'Kompyuter',
                        avatar: Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: const Text(
                    "Suring — devorgacha yoki burilishgacha yuradi",
                    style: TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final side = min(box.maxWidth - 16, box.maxHeight - 40);
                      final cell = side / size;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _gateLabel(
                              'KIRISH',
                              _maze.col(_maze.start),
                              cell,
                              side,
                              const Color(0xFF7CF5C4),
                            ),
                            SizedBox(
                              width: side,
                              height: side,
                              child: GestureDetector(
                                key: const ValueKey('maze'),
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (_) => _panStart(),
                                onPanUpdate: (d) => _panUpdate(d.delta),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _MazePainter(_maze),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _bump,
                                        builder: (_, _) => CustomPaint(
                                          painter: _LinesPainter(
                                            _maze,
                                            _me.cells,
                                            _ai.stack,
                                            _ai.visited,
                                            pawn: _pawn,
                                            // Devorga urilganda silkinish
                                            shake: _bump.isAnimating
                                                ? sin(_bump.value * pi * 4) *
                                                      (1 - _bump.value)
                                                : 0,
                                            // To'xtab turganda — qayerga yurish mumkinligi
                                            exits:
                                                _queue.isEmpty &&
                                                    _stage == _Stage.playing
                                                ? [
                                                    for (final d in const [
                                                      (-1, 0),
                                                      (1, 0),
                                                      (0, -1),
                                                      (0, 1),
                                                    ])
                                                      if (_me.canGo(d.$1, d.$2))
                                                        d,
                                                  ]
                                                : const [],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _gateLabel(
                              'CHIQISH',
                              _maze.col(_maze.exit),
                              cell,
                              side,
                              const Color(0xFFFFC233),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_stage == _Stage.ready) _startOverlay(),
            if (_stage == _Stage.countdown)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_count),
                      tween: Tween(begin: 2, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: GlowText('$_count', size: 96, color: _playerColor),
                    ),
                  ),
                ),
              ),
            if (_stage == _Stage.won || _stage == _Stage.lost)
              Positioned.fill(
                child: WinOverlay(
                  title: _stage == _Stage.won
                      ? 'Siz yutdingiz!'
                      : 'Kompyuter yutdi',
                  subtitle: _stage == _Stage.won
                      ? 'Vaqt: $_time'
                      : 'U chiqishni birinchi topdi',
                  confetti: _stage == _Stage.won,
                  color: _stage == _Stage.won ? _playerColor : _aiColor,
                  actions: [
                    GameButton(
                      label: 'Yangi labirint',
                      icon: Icons.replay_rounded,
                      colors: const [Color(0xFFFFC233), Color(0xFFB4532A)],
                      onPressed: _restart,
                    ),
                    GameButton(
                      label: 'Bosh menyu',
                      outlined: true,
                      colors: const [Colors.white70, Colors.white70],
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Labirint tepasi/pastidagi yozuv — kirish/chiqish ustuniga to'g'ri.
  Widget _gateLabel(
    String text,
    int col,
    double cell,
    double side,
    Color color,
  ) {
    return SizedBox(
      width: side,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: ((col + 0.5) * cell - 40).clamp(0.0, side - 80),
            width: 80,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _startOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Glass(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GlowText(
                  'Labirint poygasi',
                  size: 26,
                  color: _playerColor,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Qaysi tomonga sursangiz, o'sha tomonga devorgacha yurasiz.\n"
                  "Yo'lda burilish chiqsa — o'sha joyda to'xtaysiz, keyin yana surasiz.\n"
                  "Yashil chiziq — kompyuter. Undan oldin CHIQISHga yeting!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 18),
                GameButton(
                  key: const ValueKey('start'),
                  label: 'Boshlash',
                  icon: Icons.play_arrow_rounded,
                  colors: const [Color(0xFFFFC233), Color(0xFFB4532A)],
                  onPressed: _start,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// G'ishtli devorlar va qora yo'laklar.
class _MazePainter extends CustomPainter {
  final Maze maze;
  _MazePainter(this.maze);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / maze.size;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E0B0A),
    );

    const brick = Color(0xFF9A4F2C);
    final light = Paint()..color = const Color(0xFFC0703F);
    final dark = Paint()..color = const Color(0xFF5E2C16);
    final mortar = Paint()
      ..color = const Color(0xFF3A1A0C)
      ..strokeWidth = max(0.6, s * 0.07);

    for (var r = 0; r < maze.size; r++) {
      for (var c = 0; c < maze.size; c++) {
        if (!maze.isWall(r, c)) continue;
        final rect = Rect.fromLTWH(c * s, r * s, s + 0.5, s + 0.5);
        canvas.drawRect(rect, Paint()..color = brick);
        // Yorug' tepa va soyali past — hajm
        if (!maze.isWall(r - 1, c)) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, s, s * 0.18),
            light,
          );
        }
        if (!maze.isWall(r + 1, c)) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top + s * 0.8, s, s * 0.2),
            dark,
          );
        }
        // G'isht choklari
        if (s >= 7) {
          final y = rect.top + s * 0.5;
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.left + s, y),
            mortar,
          );
          final x1 = rect.left + s * ((r + c).isEven ? 0.3 : 0.7);
          final x2 = rect.left + s * ((r + c).isEven ? 0.75 : 0.25);
          canvas.drawLine(Offset(x1, rect.top), Offset(x1, y), mortar);
          canvas.drawLine(Offset(x2, y), Offset(x2, rect.top + s), mortar);
        }
      }
    }

    // Kirish va chiqish belgilari
    _gate(canvas, s, maze.start, const Color(0xFF7CF5C4), false);
    _gate(canvas, s, maze.exit, const Color(0xFFFFC233), true);
  }

  void _gate(Canvas canvas, double s, int i, Color color, bool checker) {
    final rect = Rect.fromLTWH(maze.col(i) * s, maze.row(i) * s, s, s);
    if (checker) {
      final q = s / 3;
      for (var a = 0; a < 3; a++) {
        for (var b = 0; b < 3; b++) {
          canvas.drawRect(
            Rect.fromLTWH(rect.left + a * q, rect.top + b * q, q, q),
            Paint()..color = (a + b).isEven ? Colors.white : Colors.black,
          );
        }
      }
    } else {
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.35));
    }
    canvas.drawRect(
      rect.inflate(s * 0.15),
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => old.maze != maze;
}

/// O'yinchi va kompyuter chiziqlari.
class _LinesPainter extends CustomPainter {
  final Maze maze;
  final List<int> player;
  final List<int> ai;
  final Set<int> visited;

  /// O'yinchining aniq joyi (katak birligida) va devorga urilish silkinishi.
  final Offset pawn;
  final double shake;

  /// To'xtab turganda ochiq tomonlar.
  final List<(int, int)> exits;

  _LinesPainter(
    this.maze,
    this.player,
    this.ai,
    this.visited, {
    required this.pawn,
    this.shake = 0,
    this.exits = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / maze.size;
    Offset center(int i) =>
        Offset((maze.col(i) + 0.5) * s, (maze.row(i) + 0.5) * s);

    // Kompyuter tekshirib chiqqan joylar — xira izlar
    final trace = Paint()..color = _aiColor.withValues(alpha: 0.12);
    for (final i in visited) {
      canvas.drawCircle(center(i), s * 0.16, trace);
    }

    void line(List<int> cells, Color color, double width, {Offset? head}) {
      if (cells.isEmpty) return;
      final path = Path()
        ..moveTo(center(cells.first).dx, center(cells.first).dy);
      for (final i in cells.skip(1)) {
        path.lineTo(center(i).dx, center(i).dy);
      }
      if (head != null) path.lineTo(head.dx, head.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * width * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      final h = head ?? center(cells.last);
      canvas.drawCircle(h, s * width * 0.95, Paint()..color = Colors.white);
      canvas.drawCircle(h, s * width * 0.6, Paint()..color = color);
    }

    line(ai, _aiColor, 0.32);
    final me = Offset(pawn.dx + shake * 0.15, pawn.dy) * s;
    line(player, _playerColor, 0.4, head: me);

    // O'yinchi: yorqin to'p
    canvas.drawCircle(
      me,
      s * 0.9,
      Paint()
        ..color = _playerColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5),
    );
    canvas.drawCircle(me, s * 0.42, Paint()..color = Colors.white);
    canvas.drawCircle(me, s * 0.32, Paint()..color = _playerColor);

    // Qayerga yurish mumkin — kichik strelkalar
    final arrow = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    for (final (dr, dc) in exits) {
      final dir = Offset(dc.toDouble(), dr.toDouble());
      final tip = me + dir * s * 1.05;
      final base = me + dir * s * 0.7;
      final side = Offset(-dir.dy, dir.dx) * s * 0.22;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((base + side).dx, (base + side).dy)
          ..lineTo((base - side).dx, (base - side).dy)
          ..close(),
        arrow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => true;
}
