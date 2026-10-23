import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import '../../ui/pieces.dart';
import '../../ui/setup.dart';
import 'snakes_art.dart';
import 'snakes_game.dart';

const kSnakesColors = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF43A047),
];
const kSnakesNames = ['Siz', "Ko'k", 'Sariq', 'Yashil'];

/// Sozlamalar: nechta kompyuter. Siz doim qizilsiz.
Future<int?> showSnakesSetup(BuildContext context) {
  var bots = 1;
  return showGameSetup<int>(
    context,
    title: 'Ilon va narvon',
    colors: const [Color(0xFF9CCC65), Color(0xFF2E7D32)],
    onStart: () => bots,
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLabel('Nechta kompyuter'),
        PlayerCountPicker(
          min: 1,
          max: 3,
          value: bots,
          colors: kSnakesColors.sublist(1),
          onChanged: (n) => setState(() => bots = n),
        ),
        const SizedBox(height: 6),
        Glass(
          child: Row(
            children: [
              const Icon(
                Icons.shuffle_rounded,
                color: Color(0xFFC5E1A5),
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Har o'yinda ilonlar va narvonlar yangi joyda. 100-katakka birinchi yeting!",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Ilon va narvon: siz (qizil) kompyuterlarga qarshi.
class SnakesScreen extends StatefulWidget {
  /// Jami o'yinchilar: siz + kompyuterlar
  final int players;

  /// Testlar uchun
  final int? seed;

  /// Testlar uchun tayyor o'yin
  final SnakesGame? initialGame;

  const SnakesScreen({
    super.key,
    this.players = 2,
    this.seed,
    this.initialGame,
  });

  @override
  State<SnakesScreen> createState() => _SnakesScreenState();
}

class _SnakesScreenState extends State<SnakesScreen>
    with TickerProviderStateMixin {
  static const _me = 0;
  late final Random _rnd = Random(widget.seed);
  late SnakesGame _game =
      widget.initialGame ??
      SnakesGame.random(players: widget.players, random: _rnd);

  /// Toshlarning ekrandagi joyi (katak birligida) — animatsiyadan mustaqil.
  late List<Offset> _shown = [for (final p in _game.pos) cellCenter(p)];

  /// Harakatlanayotgan tosh va uning yo'li.
  int? _moving;
  Offset Function(double t)? _path;
  late final AnimationController _anim = AnimationController(vsync: this);

  int _face = 6;
  double _diceTurns = 0;
  bool _busy = false;
  String? _note;
  int _epoch = 0;

  bool get _myTurn => !_game.finished && !_busy && _game.current == _me;

  @override
  void dispose() {
    _epoch++;
    _anim.dispose();
    super.dispose();
  }

  Future<void> _go(int ms, Offset Function(double t) path) async {
    _path = path;
    _anim.duration = Duration(milliseconds: ms);
    await _anim.forward(from: 0).orCancel.catchError((_) {});
  }

  Future<void> _roll() async {
    if (_busy || _game.finished) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _note = null;
    });
    Telegram.haptic();
    // Zar aylanadi
    for (var k = 0; k < 8; k++) {
      await Future.delayed(const Duration(milliseconds: 55));
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _face = 1 + _rnd.nextInt(6);
        _diceTurns += 0.13;
      });
    }
    final value = 1 + _rnd.nextInt(6);
    final move = _game.roll(value);
    final p = move.player;
    setState(() {
      _face = value;
      _diceTurns = _diceTurns.roundToDouble();
      _moving = p;
    });
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 250));

    // Katakma-katak sakrash
    var at = _shown[p];
    for (final cell in move.steps) {
      if (!mounted || epoch != _epoch) return;
      final from = at, to = cellCenter(cell);
      await _go(
        190,
        (t) => Offset.lerp(from, to, t)! - Offset(0, sin(pi * t) * 0.45),
      );
      at = to;
      HapticFeedback.selectionClick();
    }

    // Narvon yoki ilon
    if (move.jump != null && mounted && epoch == _epoch) {
      final landing = move.landing;
      setState(
        () => _note = move.ladder
            ? 'Narvon! ${move.landing} → ${move.to}'
            : 'Ilon! ${move.landing} → ${move.to}',
      );
      if (move.ladder) {
        HapticFeedback.mediumImpact();
        await _go(
          650,
          (t) => ladderPoint(landing, move.to, Curves.easeInOut.transform(t)),
        );
      } else {
        HapticFeedback.heavyImpact();
        final look = _game.looks[landing]!;
        await _go(
          1000,
          (t) => snakePoint(landing, move.to, look, Curves.easeIn.transform(t)),
        );
      }
    }
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _shown[p] = cellCenter(move.to);
      _moving = null;
      _busy = false;
    });
    if (_game.finished) {
      HapticFeedback.heavyImpact();
      return;
    }
    _maybeAi();
  }

  void _maybeAi() {
    if (_game.finished || _game.current == _me) return;
    final epoch = _epoch;
    setState(() => _busy = true);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || epoch != _epoch) return;
      _busy = false;
      _roll();
    });
  }

  void _newGame() {
    _epoch++;
    _anim.stop();
    setState(() {
      _game = SnakesGame.random(players: widget.players, random: _rnd);
      _shown = [for (final p in _game.pos) cellCenter(p)];
      _moving = null;
      _busy = false;
      _note = null;
    });
  }

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return GameScaffold(
      title: 'Ilon va narvon',
      palette: GamePalette.snakes,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var p = 0; p < g.players; p++)
                      PlayerBadge(
                        key: ValueKey('player-$p'),
                        color: kSnakesColors[p],
                        name: kSnakesNames[p],
                        value: g.pos[p] == 0 ? '—' : '${g.pos[p]}',
                        active: !g.finished && g.current == p,
                        avatar: SizedBox(
                          width: 16,
                          height: 22,
                          child: CustomPaint(
                            painter: PawnPainter(kSnakesColors[p]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Taxta qolgan joyga sig'adigan eng katta kvadrat
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final board = min(box.maxWidth - 20, box.maxHeight - 16);
                    return Center(
                      child: SizedBox(
                        width: board,
                        height: board,
                        child: _buildBoard(board),
                      ),
                    );
                  },
                ),
              ),
              _buildDicePanel(),
              const SizedBox(height: 12),
            ],
          ),
          if (g.finished && !_busy)
            Positioned.fill(
              child: WinOverlay(
                title: g.winner == _me
                    ? 'Siz yutdingiz!'
                    : '${kSnakesNames[g.winner!]} yutdi',
                subtitle: g.winner == _me
                    ? '100-katakka birinchi yetdingiz'
                    : "Yana bir urinib ko'ring",
                confetti: g.winner == _me,
                color: kSnakesColors[g.winner!],
                actions: [
                  GameButton(
                    label: "Yana o'ynash",
                    icon: Icons.replay_rounded,
                    colors: const [Color(0xFF9CCC65), Color(0xFF2E7D32)],
                    onPressed: _newGame,
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

  Widget _buildBoard(double size) {
    final g = _game;
    final frame = 7.0;
    final inner = size - frame * 2;
    final s = inner / SnakesGame.size;
    return Container(
      padding: EdgeInsets.all(frame),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D6E63), Color(0xFF4E342E), Color(0xFF795548)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SnakesBoardPainter(
                    g,
                    Theme.of(context).textTheme.bodyMedium!,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                // Bitta katakdagi toshlar biroz suriladi
                final order = [
                  for (var p = 0; p < g.players; p++)
                    if (p != _moving) p,
                  ?_moving,
                ];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [for (final p in order) _pawn(p, s)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pawn(int p, double s) {
    final g = _game;
    Offset pos;
    if (p == _moving && _path != null) {
      pos = _path!(_anim.value);
    } else {
      pos = _shown[p];
      final same = [
        for (var q = 0; q < g.players; q++)
          if (q != _moving && (_shown[q] - pos).distance < 0.01) q,
      ];
      if (same.length > 1) {
        final k = same.indexOf(p);
        pos += Offset((k - (same.length - 1) / 2) * 0.28, (k.isEven ? 0 : 0.1));
      }
    }
    final w = s * 0.56, h = s * 0.78;
    final active = !g.finished && g.current == p && p == _me && !_busy;
    return Positioned(
      key: ValueKey('pawn-$p'),
      left: pos.dx * s - w / 2,
      top: pos.dy * s - h * 0.85,
      width: w,
      height: h,
      child: IgnorePointer(
        child: CustomPaint(
          painter: PawnPainter(kSnakesColors[p], highlight: active),
        ),
      ),
    );
  }

  Widget _buildDicePanel() {
    final g = _game;
    final color = kSnakesColors[g.current];
    final String text;
    if (_note != null) {
      text = _note!;
    } else if (g.finished) {
      text = '';
    } else if (g.current == _me) {
      text = _busy ? 'Yuryapsiz…' : 'Zarni bosing!';
    } else {
      text = "${kSnakesNames[g.current]} o'ylayapti…";
    }
    final noteColor = _note == null
        ? color
        : _note!.startsWith('Narvon')
        ? const Color(0xFFC5E1A5)
        : const Color(0xFFFF8A80);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: FittedBox(
                  key: ValueKey(text),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: GlowText(text, size: 20, color: noteColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              key: const ValueKey('dice'),
              onTap: _myTurn ? _roll : null,
              child: Dice3D(
                value: _face,
                turns: _diceTurns,
                color: color,
                glowing: _myTurn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
