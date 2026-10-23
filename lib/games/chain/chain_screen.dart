import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import 'chain_game.dart';
import '../../ui/kit.dart';
import '../../ui/setup.dart';

const kChainColors = [
  Color(0xFFFF5252),
  Color(0xFF40C4FF),
  Color(0xFFFFD740),
  Color(0xFF69F0AE),
  Color(0xFFB388FF),
  Color(0xFFFF9100),
  Color(0xFFFF80AB),
  Color(0xFFECEFF1),
];
const kChainNames = [
  'Qizil', "Ko'k", 'Sariq', 'Yashil', 'Binafsha', "To'q sariq", 'Pushti', 'Oq',
];

/// O'yin sozlamalari: o'yinchilar soni va taxta o'lchami.
Future<({int players, int rows, int cols})?> showChainSetup(BuildContext context) {
  var players = 2;
  var big = false;
  return showGameSetup(
    context,
    title: 'Chain Reaction',
    colors: const [Color(0xFFFF4D8D), Color(0xFF7B2FF7)],
    onStart: () => (players: players, rows: big ? 12 : 9, cols: big ? 8 : 6),
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLabel("O'yinchilar soni"),
        PlayerCountPicker(
          min: 2,
          max: 8,
          value: players,
          colors: kChainColors,
          onChanged: (n) => setState(() => players = n),
        ),
        const SizedBox(height: 6),
        const SetupLabel('Taxta'),
        ChoiceRow(children: [
          ChoiceCard(
            selected: !big,
            color: const Color(0xFFFF4D8D),
            icon: const MiniGrid(cols: 6, rows: 9, color: Colors.white),
            label: '6 × 9',
            hint: "tez o'yin",
            onTap: () => setState(() => big = false),
          ),
          ChoiceCard(
            selected: big,
            color: const Color(0xFFFF4D8D),
            icon: const MiniGrid(cols: 8, rows: 12, color: Colors.white),
            label: '8 × 12',
            hint: "ko'p kishiga",
            onTap: () => setState(() => big = true),
          ),
        ]),
      ],
    ),
  );
}

class ChainScreen extends StatefulWidget {
  final int players;
  final int rows;
  final int cols;

  const ChainScreen(
      {super.key, this.players = 2, this.rows = 9, this.cols = 6});

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen>
    with SingleTickerProviderStateMixin {
  late final ChainGame _game =
      ChainGame(rows: widget.rows, cols: widget.cols, players: widget.players);

  /// Hozir portlayotgan kataklar (chaqnash uchun) va to'lqin raqami.
  Set<int> _flash = {};
  int _wave = 0;

  /// Portlash arafasidagi sharlarning titrashi.
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..repeat();

  static const _waveDelay = Duration(milliseconds: 170);

  @override
  void initState() {
    super.initState();
    _shake; // kechiktirilgan yaratilish dispose paytida xato bermasligi uchun
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tap(int i) async {
    if (!_game.place(i)) return;
    setState(() {});
    // Portlashlar to'lqin-to'lqin
    while (mounted) {
      await Future.delayed(_waveDelay);
      if (!mounted) return;
      final burst = _game.step();
      if (burst.isEmpty) break;
      HapticFeedback.lightImpact();
      Telegram.haptic();
      setState(() {
        _flash = burst.toSet();
        _wave++;
      });
    }
    if (!mounted) return;
    setState(() {
      _game.endTurn();
      _flash = {};
    });
  }


  void _restart() => setState(() {
        _game.newRound();
        _game.round--; // qayta boshlash raund hisoblanmaydi
        _flash = {};
      });

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final turnColor = kChainColors[g.finished ? g.winner! : g.current];

    return GameScaffold(
      title: 'Chain Reaction',
      palette: GamePalette.chain,
      actions: [
        IconButton(
          tooltip: 'Yurishni qaytarish',
          icon: const Icon(Icons.undo_rounded),
          onPressed: g.canUndo ? () => setState(g.undo) : null,
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var p = 0; p < g.players; p++)
                      PlayerBadge(
                        color: kChainColors[p],
                        name: '${kChainNames[p]}${g.score[p] > 0 ? ' ★${g.score[p]}' : ''}',
                        value: '${g.orbsOf(p)}',
                        active: p == g.current && !g.finished,
                        dimmed: !g.isAlive(p),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: g.finished
                    ? null
                    : GlowText('${kChainNames[g.current]} navbati', size: 20, color: turnColor),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AspectRatio(
                      aspectRatio: g.cols / g.rows,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0612),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: turnColor.withValues(alpha: 0.9), width: 2),
                          boxShadow: [
                            BoxShadow(color: turnColor.withValues(alpha: 0.45), blurRadius: 22),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: g.cols),
                            itemCount: g.cells,
                            itemBuilder: (context, i) => _buildCell(i, turnColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 12, 40, 4),
                child: GameButton(
                  label: 'Qaytadan boshlash',
                  icon: Icons.refresh_rounded,
                  outlined: true,
                  colors: [turnColor, turnColor],
                  onPressed: g.exploding || g.finished ? null : _restart,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${g.round}-raund',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
          if (g.finished)
            Positioned.fill(
              child: WinOverlay(
                key: ValueKey('win-${g.round}'),
                title: '${kChainNames[g.winner!]} yutdi!',
                subtitle: 'Butun taxtani egalladi',
                color: kChainColors[g.winner!],
                actions: [
                  GameButton(
                    label: "Yana o'ynash",
                    icon: Icons.replay_rounded,
                    colors: [kChainColors[g.winner!], const Color(0xFF7B2FF7)],
                    onPressed: () => setState(g.newRound),
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

  Widget _buildCell(int i, Color gridColor) {
    final g = _game;
    final n = g.count[i];
    final color = g.owner[i] >= 0 ? kChainColors[g.owner[i]] : Colors.white;
    final flashing = _flash.contains(i);
    final critical = g.isCritical(i) && !g.finished;

    return GestureDetector(
      key: ValueKey('cell-$i'),
      onTap: g.canPlace(i) ? () => _tap(i) : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: gridColor.withValues(alpha: 0.28), width: 0.6),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (flashing)
              TweenAnimationBuilder<double>(
                key: ValueKey('flash-$_wave-$i'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                builder: (_, t, _) => CustomPaint(painter: _FlashPainter(t, color)),
              ),
            if (n > 0)
              AnimatedBuilder(
                animation: _shake,
                builder: (_, _) => CustomPaint(
                  painter: _OrbsPainter(
                    n,
                    color,
                    critical ? _shake.value : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Katakdagi sharlar (1–3 ta, ko'p bo'lsa son), portlash arafasida titraydi.
class _OrbsPainter extends CustomPainter {
  final int count;
  final Color color;
  final double? shake;
  _OrbsPainter(this.count, this.color, this.shake);

  static const _layouts = <List<Offset>>[
    [],
    [Offset(0, 0)],
    [Offset(-0.2, 0), Offset(0.2, 0)],
    [Offset(0, -0.2), Offset(-0.2, 0.17), Offset(0.2, 0.17)],
    [Offset(-0.2, -0.2), Offset(0.2, -0.2), Offset(-0.2, 0.2), Offset(0.2, 0.2)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final r = s * 0.2;
    var jitter = Offset.zero;
    if (shake != null) {
      final t = shake! * 2 * pi;
      jitter = Offset(sin(t * 3), cos(t * 2)) * s * 0.03;
    }
    final layout = _layouts[min(count, 4)];

    // Umumiy nur
    canvas.drawCircle(
      c,
      s * 0.42,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: shake != null ? 0.45 : 0.25),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: s * 0.42)),
    );
    for (final o in layout) {
      final p = c + o * s + jitter;
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [
              Colors.white,
              Color.lerp(color, Colors.white, 0.35)!,
              color,
              Color.lerp(color, Colors.black, 0.45)!,
            ],
            stops: const [0, 0.18, 0.55, 1],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
    }
    if (count > 4) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: s * 0.3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter old) =>
      old.count != count || old.color != color || old.shake != shake;
}

/// Portlash: kengayuvchi halqa va uchqunlar.
class _FlashPainter extends CustomPainter {
  final double t;
  final Color color;
  _FlashPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r * (0.4 + t * 0.9),
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.9 * (1 - t)),
          color.withValues(alpha: 0.7 * (1 - t)),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.3)),
    );
    for (var k = 0; k < 4; k++) {
      final a = k * pi / 2;
      final p = c + Offset(cos(a), sin(a)) * r * (0.3 + t);
      canvas.drawCircle(p, r * 0.12 * (1 - t), Paint()..color = Colors.white.withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant _FlashPainter old) => old.t != t;
}
