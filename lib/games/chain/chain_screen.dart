import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import 'chain_game.dart';

const kChainColors = [
  Color(0xFFFF5252),
  Color(0xFF40C4FF),
  Color(0xFFFFD740),
  Color(0xFF69F0AE),
];
const kChainNames = ['Qizil', "Ko'k", 'Sariq', 'Yashil'];

/// O'yin sozlamalari: o'yinchilar soni va taxta o'lchami.
Future<({int players, int rows, int cols})?> showChainSetup(
    BuildContext context) {
  var players = 2;
  var big = false;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Chain Reaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("O'yinchilar"),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {players},
              onSelectionChanged: (s) => setState(() => players = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Taxta'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('6 × 9')),
                ButtonSegment(value: true, label: Text('8 × 12')),
              ],
              selected: {big},
              onSelectionChanged: (s) => setState(() => big = s.first),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, (
              players: players,
              rows: big ? 12 : 9,
              cols: big ? 8 : 6,
            )),
            child: const Text('Boshlash'),
          ),
        ],
      ),
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

  /// Hozir portlayotgan kataklar (chaqnash uchun).
  Set<int> _flash = {};

  /// Portlash arafasidagi sharlarning titrashi.
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..repeat();

  static const _waveDelay = Duration(milliseconds: 170);

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
      setState(() => _flash = burst.toSet());
    }
    if (!mounted) return;
    setState(() {
      _game.endTurn();
      _flash = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final turnColor = kChainColors[g.finished ? g.winner! : g.current];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chain Reaction'),
        actions: [
          IconButton(
            tooltip: 'Yurishni qaytarish',
            icon: const Icon(Icons.undo),
            onPressed: g.canUndo ? () => setState(g.undo) : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---- o'yinchilar ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var p = 0; p < g.players; p++)
                    Chip(
                      avatar: CircleAvatar(backgroundColor: kChainColors[p]),
                      label: Text(
                        '${kChainNames[p]}  ${g.orbsOf(p)}  ★${g.score[p]}',
                        style: TextStyle(
                          decoration: g.isAlive(p)
                              ? null
                              : TextDecoration.lineThrough,
                          fontWeight: p == g.current && !g.finished
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      side: p == g.current && !g.finished
                          ? BorderSide(color: kChainColors[p], width: 2)
                          : null,
                    ),
                ],
              ),
            ),
            Text(
              g.finished
                  ? '${kChainNames[g.winner!]} yutdi!'
                  : '${kChainNames[g.current]} navbati',
              style: text.titleMedium?.copyWith(color: turnColor),
            ),
            const SizedBox(height: 8),

            // ---- taxta ----
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(
                    aspectRatio: g.cols / g.rows,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: turnColor.withValues(alpha: 0.8), width: 1),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: g.cols),
                        itemCount: g.cells,
                        itemBuilder: (context, i) => _buildCell(i, turnColor),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: g.finished
                    ? FilledButton(
                        onPressed: () => setState(g.newRound),
                        child: const Text("Yana o'ynash"))
                    : OutlinedButton(
                        onPressed: g.exploding
                            ? null
                            : () => setState(() {
                                  g.newRound();
                                  g.round--; // qayta boshlash raund hisoblanmaydi
                                }),
                        child: const Text('Qaytadan boshlash')),
              ),
            ),
            Text('${g.round}-raund', style: text.bodySmall),
            const SizedBox(height: 4),
          ],
        ),
      ),
      backgroundColor: scheme.surface,
    );
  }

  Widget _buildCell(int i, Color gridColor) {
    final g = _game;
    final n = g.count[i];
    final color = g.owner[i] >= 0 ? kChainColors[g.owner[i]] : null;
    final flashing = _flash.contains(i);

    Widget orbs = _Orbs(count: n, color: color ?? Colors.white);
    if (g.isCritical(i) && !g.finished) {
      // Yana bitta shar — portlaydi: titraydi
      orbs = AnimatedBuilder(
        animation: _shake,
        builder: (_, child) {
          final t = _shake.value * 2 * pi;
          return Transform.translate(
            offset: Offset(sin(t * 3) * 1.2, cos(t * 2) * 1.2),
            child: child,
          );
        },
        child: orbs,
      );
    }

    return GestureDetector(
      key: ValueKey('cell-$i'),
      onTap: g.canPlace(i) ? () => _tap(i) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: flashing && color != null
              ? color.withValues(alpha: 0.35)
              : Colors.transparent,
          border: Border.all(color: gridColor.withValues(alpha: 0.35), width: 0.5),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey('${g.owner[i]}-$n'),
            child: n == 0 ? const SizedBox.expand() : orbs,
          ),
        ),
      ),
    );
  }
}

/// Katakdagi sharlar: 1, 2, 3 ta (yoki ko'proq bo'lsa son).
class _Orbs extends StatelessWidget {
  final int count;
  final Color color;

  const _Orbs({required this.count, required this.color});

  static const _layouts = <List<Alignment>>[
    [],
    [Alignment.center],
    [Alignment(-0.4, 0), Alignment(0.4, 0)],
    [Alignment(0, -0.4), Alignment(-0.4, 0.35), Alignment(0.4, 0.35)],
    [
      Alignment(-0.4, -0.4),
      Alignment(0.4, -0.4),
      Alignment(-0.4, 0.4),
      Alignment(0.4, 0.4),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final layout = _layouts[min(count, 4)];
    return LayoutBuilder(builder: (context, box) {
      final d = box.maxWidth * 0.36;
      return Stack(
        children: [
          for (final a in layout)
            Align(
              alignment: a,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    colors: [Color.lerp(color, Colors.white, 0.5)!, color],
                  ),
                ),
              ),
            ),
          if (count > 4)
            Center(
              child: Text('$count',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      );
    });
  }
}
