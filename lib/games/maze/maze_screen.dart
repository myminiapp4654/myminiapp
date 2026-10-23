import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import 'maze_game.dart';

const _playerColor = Color(0xFFFFC233);
const _aiColor = Color(0xFF4CFF7A);

enum _Stage { ready, countdown, playing, won, lost }

/// Labirint musobaqasi: siz barmoq bilan yo'l chizasiz, kompyuter qidiradi.
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
  late PlayerPath _path = PlayerPath(_maze);
  late MazeRunner _ai = MazeRunner(_maze, widget.level, _rnd);

  _Stage _stage = _Stage.ready;
  int _count = 3;
  int _epoch = 0;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _aiDebt = 0;
  final _clock = Stopwatch();

  /// Devorga tegilganda qizil miltillash.
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  int _hits = 0;

  /// Barmoq chiziq uchidan uzoqda qo'yildi — maslahat.
  bool _hint = false;

  @override
  void dispose() {
    _epoch++;
    _ticker.dispose();
    _flash.dispose();
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
      _path = PlayerPath(_maze);
      _ai = MazeRunner(_maze, widget.level, _rnd);
      _hits = 0;
      _hint = false;
    });
    _start();
  }

  void _finish(bool won) {
    _ticker.stop();
    _clock.stop();
    _path.stop();
    HapticFeedback.heavyImpact();
    setState(() => _stage = won ? _Stage.won : _Stage.lost);
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (_stage != _Stage.playing) return;
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

  // ---------------------------------------------------------------- barmoq

  Offset _toCells(Offset local, double cell) => local / cell;

  void _down(Offset local, double cell) {
    if (_stage != _Stage.playing) return;
    final p = _toCells(local, cell);
    final ok = _path.begin(p.dx, p.dy);
    setState(() => _hint = !ok);
  }

  void _drag(Offset local, double cell) {
    if (_stage != _Stage.playing || !_path.drawing) return;
    final p = _toCells(local, cell);
    final ok = _path.move(p.dx, p.dy);
    if (!ok) {
      // Devorga tegdi: chizish uziladi, ekran qizil miltillaydi
      _hits++;
      HapticFeedback.heavyImpact();
      Telegram.haptic();
      _flash.forward(from: 0);
    }
    if (_path.finished) {
      _finish(true);
      return;
    }
    setState(() {});
  }

  void _up() {
    _path.stop();
    setState(() {});
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
      body: Stack(
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
                child: Text(
                  _hint
                      ? 'Chiziq uchidan davom eting'
                      : _hits > 0
                      ? 'Devorga tegdingiz: $_hits marta'
                      : 'KIRISHdan CHIQISHgacha yo\'l chizing',
                  style: TextStyle(
                    color: _hint || _hits > 0
                        ? const Color(0xFFFF8A80)
                        : Colors.white60,
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
                              onPanStart: (d) => _down(d.localPosition, cell),
                              onPanUpdate: (d) => _drag(d.localPosition, cell),
                              onPanEnd: (_) => _up(),
                              onPanCancel: _up,
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
                                    child: CustomPaint(
                                      painter: _LinesPainter(
                                        _maze,
                                        _path.cells,
                                        _ai.stack,
                                        _ai.visited,
                                        drawing: _path.drawing,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: _flash,
                                        builder: (_, _) => ColoredBox(
                                          color: const Color(0xFFFF1744)
                                              .withValues(
                                                alpha:
                                                    0.45 *
                                                    (1 - _flash.value) *
                                                    (_flash.isAnimating
                                                        ? 1
                                                        : 0),
                                              ),
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
                    ? 'Vaqt: $_time  •  devorga tegish: $_hits'
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
                  "Barmog'ingiz bilan KIRISHdan CHIQISHgacha yo'l chizing.\n"
                  "Devorga tegsangiz chiziq uziladi — barmoqni ko'tarib, chiziq uchidan davom eting.\n"
                  "Yashil chiziq — kompyuter. Undan oldin chiqing!",
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
  final bool drawing;

  _LinesPainter(
    this.maze,
    this.player,
    this.ai,
    this.visited, {
    required this.drawing,
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

    void line(List<int> cells, Color color, double width) {
      if (cells.isEmpty) return;
      final path = Path()
        ..moveTo(center(cells.first).dx, center(cells.first).dy);
      for (final i in cells.skip(1)) {
        path.lineTo(center(i).dx, center(i).dy);
      }
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
      final head = center(cells.last);
      canvas.drawCircle(head, s * width * 0.95, Paint()..color = Colors.white);
      canvas.drawCircle(head, s * width * 0.6, Paint()..color = color);
    }

    line(ai, _aiColor, 0.32);
    line(player, _playerColor, 0.46);
    if (drawing) {
      canvas.drawCircle(
        center(player.last),
        s * 0.9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.12
          ..color = _playerColor.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter old) => true;
}
