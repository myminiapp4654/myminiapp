import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/crown.dart';
import '../../ui/kit.dart';
import 'checkers_ai.dart';
import 'checkers_game.dart';

const _ivory = Color(0xFFF3E9D2);
const _ebony = Color(0xFF2B2B2B);

/// Shashka: siz (oq, pastda, birinchi yurasiz) kompyuterga qarshi.
class CheckersScreen extends StatefulWidget {
  /// Kompyuter darajasi: 1 — oson, 2 — o'rta, 3 — qiyin
  final int level;

  /// Testlar uchun
  final int? seed;

  const CheckersScreen({super.key, this.level = 2, this.seed});

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen>
    with SingleTickerProviderStateMixin {
  final _game = CheckersGame();
  late final Random _rnd = Random(widget.seed);
  int? _selected;
  int _moveCount = 0;
  static const _me = 'w', _ai = 'b';

  /// Kompyuter yurishi davom etyapti (qadamlar birin-ketin ko'rsatiladi).
  Timer? _aiTimer;

  bool get _myTurn => !_game.finished && _game.turn == _me && _aiTimer == null;

  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  static String _who(String c) => c == _me ? 'Siz' : 'Kompyuter';

  @override
  void dispose() {
    _aiTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Kompyuter navbati bo'lsa — o'ylab, qadamlarni birin-ketin yuradi.
  void _maybeAi() {
    if (_game.finished || _game.turn != _ai || _aiTimer != null) return;
    _aiTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final steps = checkersAiTurn(_game, widget.level, _rnd);
      _playSteps(steps, 0);
    });
  }

  void _playSteps(List<CheckersMove> steps, int k) {
    if (!mounted) return;
    if (k >= steps.length) {
      setState(() => _aiTimer = null);
      return;
    }
    final m = steps[k];
    setState(() {
      _game.play(m.from, m.to);
      _moveCount++;
    });
    m.isCapture ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    _aiTimer = Timer(const Duration(milliseconds: 380), () => _playSteps(steps, k + 1));
  }

  void _tap(int i, List<CheckersMove> moves) {
    if (!_myTurn) return;
    final from = _game.chain ?? _selected;
    if (from != null && moves.any((m) => m.from == from && m.to == i)) {
      final capture = moves.any((m) => m.from == from && m.to == i && m.isCapture);
      Telegram.haptic();
      capture ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
      setState(() {
        _game.play(from, i);
        _selected = null;
        _moveCount++;
      });
      _maybeAi();
      return;
    }
    if (_game.chain != null) return; // zanjirli urishda boshqa dona tanlanmaydi
    setState(() {
      _selected = moves.any((m) => m.from == i) ? i : null;
    });
  }

  void _newRound() {
    _aiTimer?.cancel();
    _aiTimer = null;
    setState(() {
      _game.newRound();
      _selected = null;
      _moveCount++;
    });
  }

  String _status() {
    final g = _game;
    if (g.winner == 'draw') return 'Durang';
    if (g.finished) return g.winner == _me ? 'Siz yutdingiz!' : 'Kompyuter yutdi';
    if (g.turn == _ai) return "Kompyuter o'ylayapti…";
    if (g.chain != null) return 'Urishni davom ettiring';
    if (g.mustCapture) return 'Sizning navbatingiz — urish majburiy';
    return 'Sizning navbatingiz';
  }

  Widget _badge(String color) {
    final g = _game;
    return PlayerBadge(
      color: color == 'w' ? _ivory : const Color(0xFF555555),
      name: _who(color),
      value: '${g.count(color)}',
      active: !g.finished && g.turn == color,
      avatar: SizedBox(
        width: 26,
        height: 26,
        child: CustomPaint(painter: _DiscPainter(color == 'w' ? 'w' : 'b')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final status = _status();
    final urgent = _myTurn && g.mustCapture;

    return GameScaffold(
      title: 'Shashka',
      palette: GamePalette.checkers,
      body: Stack(
        children: [
          LayoutBuilder(builder: (context, box) {
            final board = (box.maxWidth - 16).clamp(0.0, box.maxHeight - 230);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: Align(alignment: Alignment.centerLeft, child: _badge('b'))),
                      const SizedBox(width: 10),
                      Expanded(child: Align(alignment: Alignment.centerRight, child: _badge('w'))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(width: board, height: board, child: _buildBoard()),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(status),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: urgent
                          ? const Color(0xFFFF8A3D).withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Text(status,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
                Text("Hisob ${g.score['w']} : ${g.score['b']}  •  ${g.round}-raund  •  durang: ${g.draws}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GameButton(
                          label: 'Qaytadan',
                          icon: Icons.refresh_rounded,
                          outlined: true,
                          colors: const [Color(0xFFFFB347), Color(0xFFFF6A3D)],
                          onPressed: _newRound,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          if (g.finished)
            Positioned.fill(
              child: WinOverlay(
                title: g.winner == 'draw'
                    ? 'Durang'
                    : g.winner == _me
                        ? 'Siz yutdingiz!'
                        : 'Kompyuter yutdi',
                subtitle: "Hisob: Siz ${g.score['w']} : ${g.score['b']} Kompyuter",
                confetti: g.winner == _me,
                color: const Color(0xFFFFB347),
                actions: [
                  GameButton(
                      label: "Yana o'ynash", icon: Icons.replay_rounded, onPressed: _newRound),
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

  Widget _buildBoard() {
    final g = _game;
    final moves = _myTurn ? g.legalMoves() : const <CheckersMove>[];
    final selected = g.chain ?? _selected;
    final targets = {
      for (final m in moves)
        if (m.from == selected) m.to: m.isCapture,
    };
    final movable = {for (final m in moves) m.from};

    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A4A24), Color(0xFF3B2010), Color(0xFF6A3E1C)],
        ),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(builder: (context, box) {
          final s = box.maxWidth / 8;
          Offset pos(int i) => Offset((i % 8) * s, (i ~/ 8) * s);

          final squares = <Widget>[];
          final pieces = <Widget>[];
          for (var i = 0; i < 64; i++) {
            final dark = (i ~/ 8 + i % 8).isOdd;
            var bg = dark ? const Color(0xFF8B5A2B) : const Color(0xFFF0DDB8);
            if (dark && (i == g.lastFrom || i == g.lastTo)) {
              bg = Color.lerp(bg, const Color(0xFFFFC857), 0.35)!;
            }
            if (i == selected) bg = Color.lerp(bg, const Color(0xFF7FC97F), 0.6)!;
            final p = pos(i);
            final isTarget = targets.containsKey(i);
            squares.add(Positioned(
              left: p.dx,
              top: p.dy,
              width: s,
              height: s,
              child: GestureDetector(
                key: ValueKey('sq-$i'),
                onTap: dark && !g.finished ? () => _tap(i, moves) : null,
                child: Container(
                  color: bg,
                  child: isTarget
                      ? Center(
                          child: AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, _) => Container(
                              width: s * (targets[i]! ? 0.8 : 0.32),
                              height: s * (targets[i]! ? 0.8 : 0.32),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: targets[i]!
                                    ? null
                                    : const Color(0xFF7CFF8A).withValues(alpha: 0.5 + 0.3 * _pulse.value),
                                border: targets[i]!
                                    ? Border.all(
                                        color: const Color(0xFFFF5252).withValues(alpha: 0.6 + 0.4 * _pulse.value),
                                        width: 3)
                                    : null,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ));

            final piece = g.board[i];
            if (piece.isEmpty) continue;
            final canMove = !g.finished && g.chain == null && movable.contains(i) && i != selected;
            final disc = IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Container(
                  margin: EdgeInsets.all(s * 0.08),
                  decoration: canMove
                      ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFC857).withValues(alpha: 0.4 + 0.4 * _pulse.value),
                            blurRadius: 8 + 6 * _pulse.value,
                            spreadRadius: 1,
                          ),
                        ])
                      : null,
                  child: child,
                ),
                child: AnimatedScale(
                  scale: i == selected ? 1.12 : 1,
                  duration: const Duration(milliseconds: 120),
                  child: Opacity(
                    opacity: g.captured.contains(i) ? 0.35 : 1,
                    child: CustomPaint(painter: _DiscPainter(piece)),
                  ),
                ),
              ),
            );
            final to = pos(i);
            if (i == g.lastTo && g.lastFrom != null) {
              pieces.add(TweenAnimationBuilder<Offset>(
                key: ValueKey('mv-$_moveCount'),
                tween: Tween(begin: pos(g.lastFrom!), end: to),
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                builder: (_, o, child) =>
                    Positioned(left: o.dx, top: o.dy, width: s, height: s, child: child!),
                child: disc,
              ));
            } else {
              pieces.add(Positioned(left: to.dx, top: to.dy, width: s, height: s, child: disc));
            }
          }
          return Stack(children: [...squares, ...pieces]);
        }),
      ),
    );
  }
}

/// Hajmli shashka donasi; damkada oltin toj.
class _DiscPainter extends CustomPainter {
  final String piece;
  _DiscPainter(this.piece);

  @override
  void paint(Canvas canvas, Size size) {
    final white = piece.toLowerCase() == 'w';
    final king = piece == 'W' || piece == 'B';
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final base = white ? _ivory : _ebony;

    // Soya va qalinlik (pastki qatlam)
    canvas.drawCircle(c + Offset(0, r * 0.14), r * 0.98,
        Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawCircle(c + Offset(0, r * 0.07), r * 0.98,
        Paint()..color = Color.lerp(base, Colors.black, white ? 0.35 : 0.5)!);
    // Yuz
    canvas.drawCircle(
      c,
      r * 0.95,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Color.lerp(base, Colors.white, white ? 0.6 : 0.25)!,
            base,
            Color.lerp(base, Colors.black, 0.3)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Halqalar
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.07
      ..color = (white ? Colors.brown : Colors.white).withValues(alpha: 0.22);
    canvas.drawCircle(c, r * 0.72, ring);
    canvas.drawCircle(c, r * 0.48, ring);
    if (king) {
      paintCrown(canvas, Rect.fromCenter(center: c, width: r * 1.15, height: r * 0.95));
    }
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.piece != piece;
}
