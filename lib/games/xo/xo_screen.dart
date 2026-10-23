import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import 'xo_game.dart';

const _xColor = Color(0xFF4DE8FF);
const _oColor = Color(0xFFFF5FA2);

Color _markColor(String m) => m == 'X' ? _xColor : _oColor;

/// X-O: bitta telefonda ikki kishi navbatma-navbat o'ynaydi.
class XoScreen extends StatefulWidget {
  final int size;

  const XoScreen({super.key, required this.size});

  @override
  State<XoScreen> createState() => _XoScreenState();
}

class _XoScreenState extends State<XoScreen> {
  late final XoGame _game = XoGame(widget.size);

  void _tap(int i) {
    if (!_game.play(i)) return;
    Telegram.haptic();
    _game.finished
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.selectionClick();
    setState(() {});
  }

  void _again() => setState(_game.newRound);

  Widget _side(String mark) {
    final g = _game;
    final active = !g.finished && g.turn == mark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _markColor(mark).withValues(alpha: active ? 0.18 : 0.05),
        border: Border.all(
          color: _markColor(mark).withValues(alpha: active ? 1 : 0.25),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _markColor(mark).withValues(alpha: 0.6),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: CustomPaint(painter: _MarkPainter(mark, 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final status = !g.finished ? '${g.turn} navbati' : '';

    return GameScaffold(
      title: 'X-O ${g.size}×${g.size}',
      palette: GamePalette.xo,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final board = min(box.maxWidth - 24, box.maxHeight - 230);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _side('X'),
                      const SizedBox(width: 14),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            children: [
                              Text(
                                'X  ${g.score['X']} : ${g.score['O']}  O',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '${g.round}-raund  •  durang: ${g.draws}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      _side('O'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 30,
                    child: status.isEmpty
                        ? null
                        : GlowText(status, size: 20, color: _markColor(g.turn)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(width: board, height: board, child: _buildBoard()),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: GameButton(
                      label: 'Qaytadan boshlash',
                      icon: Icons.refresh_rounded,
                      outlined: true,
                      colors: const [_xColor, _oColor],
                      onPressed: g.finished ? null : _again,
                    ),
                  ),
                ],
              );
            },
          ),
          if (g.finished)
            Positioned.fill(
              child: WinOverlay(
                key: ValueKey('win-${g.round}'),
                title: g.winner == 'draw' ? 'Durang' : '${g.winner} yutdi!',
                subtitle: 'Hisob ${g.score['X']} : ${g.score['O']}',
                confetti: g.winner != 'draw',
                color: g.winner == 'draw'
                    ? Colors.white
                    : _markColor(g.winner!),
                actions: [
                  GameButton(
                    label: "Yana o'ynash",
                    icon: Icons.replay_rounded,
                    colors: const [_xColor, Color(0xFF7B5CFF)],
                    onPressed: _again,
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

  Widget _buildBoard() {
    final g = _game;
    final big = g.size == 3;
    return Glass(
      padding: EdgeInsets.all(big ? 12 : 6),
      radius: 24,
      child: LayoutBuilder(
        builder: (context, box) {
          final gap = big ? 10.0 : 2.0;
          final s = (box.maxWidth - gap * (g.size - 1)) / g.size;
          Offset center(int i) => Offset(
            (i % g.size) * (s + gap) + s / 2,
            (i ~/ g.size) * (s + gap) + s / 2,
          );

          return Stack(
            children: [
              for (var i = 0; i < g.board.length; i++)
                Positioned(
                  left: (i % g.size) * (s + gap),
                  top: (i ~/ g.size) * (s + gap),
                  width: s,
                  height: s,
                  child: GestureDetector(
                    key: ValueKey('cell-$i'),
                    onTap: !g.finished && g.board[i].isEmpty
                        ? () => _tap(i)
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(big ? 18 : 3),
                        color: g.line.contains(i)
                            ? _markColor(g.board[i]).withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: big ? 0.06 : 0.04),
                        border: Border.all(
                          color: g.lastMove == i && !g.finished
                              ? _markColor(g.board[i]).withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      padding: EdgeInsets.all(s * 0.2),
                      child: g.board[i].isEmpty
                          ? null
                          : TweenAnimationBuilder<double>(
                              key: ValueKey('m-${g.round}-$i'),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              builder: (_, t, _) => CustomPaint(
                                painter: _MarkPainter(
                                  g.board[i],
                                  t,
                                  thin: !big,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              if (g.line.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('line-${g.round}'),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, _) => CustomPaint(
                        painter: _WinLinePainter(
                          center(g.line.first),
                          center(g.line.last),
                          t,
                          _markColor(g.winner ?? 'X'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Neon X yoki O; [t] — chizilish jarayoni (0..1).
class _MarkPainter extends CustomPainter {
  final String mark;
  final double t;
  final bool thin;
  _MarkPainter(this.mark, this.t, {this.thin = false});

  @override
  void paint(Canvas canvas, Size size) {
    final color = _markColor(mark);
    final w = size.shortestSide * (thin ? 0.16 : 0.14);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = w * 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.8);
    final core = Paint()
      ..color = Color.lerp(color, Colors.white, 0.35)!
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (mark == 'X') {
      final a = (t * 2).clamp(0.0, 1.0), b = (t * 2 - 1).clamp(0.0, 1.0);
      void line(Offset p, Offset q, double k) {
        if (k <= 0) return;
        final e = Offset.lerp(p, q, k)!;
        canvas.drawLine(p, e, glow);
        canvas.drawLine(p, e, core);
      }

      line(Offset.zero, Offset(size.width, size.height), a);
      line(Offset(size.width, 0), Offset(0, size.height), b);
    } else {
      final rect = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
      canvas.drawArc(rect, -pi / 2, 2 * pi * t, false, glow);
      canvas.drawArc(rect, -pi / 2, 2 * pi * t, false, core);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) =>
      old.t != t || old.mark != mark;
}

class _WinLinePainter extends CustomPainter {
  final Offset a, b;
  final double t;
  final Color color;
  _WinLinePainter(this.a, this.b, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Chiziq kataklardan biroz chiqib turadi
    final dir = b - a;
    final ext = dir.distance == 0 ? Offset.zero : dir / dir.distance * 18;
    final p = a - ext, q = b + ext;
    final e = Offset.lerp(p, q, t)!;
    canvas.drawLine(
      p,
      e,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      p,
      e,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WinLinePainter old) => old.t != t;
}
