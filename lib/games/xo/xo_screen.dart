import 'package:flutter/material.dart';

import 'xo_game.dart';

/// X-O: bitta telefonda ikki kishi navbatma-navbat o'ynaydi.
class XoScreen extends StatefulWidget {
  final int size;

  const XoScreen({super.key, required this.size});

  @override
  State<XoScreen> createState() => _XoScreenState();
}

class _XoScreenState extends State<XoScreen> {
  late final XoGame _game = XoGame(widget.size);

  void _tap(int i) => setState(() => _game.play(i));

  void _again() => setState(_game.newRound);

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Color markColor(String m) => m == 'X' ? scheme.primary : scheme.tertiary;

    final status = !g.finished
        ? '${g.turn} navbati'
        : g.winner == 'draw'
            ? 'Durang'
            : '${g.winner} yutdi!';

    return Scaffold(
      appBar: AppBar(title: Text('X-O ${g.size}×${g.size}')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text('X  ${g.score['X']} : ${g.score['O']}  O', style: text.titleLarge),
          Text('${g.round}-raund  •  durang: ${g.draws}', style: text.bodySmall),
          const SizedBox(height: 12),
          Text(status,
              style: text.titleMedium?.copyWith(
                  color: g.finished && g.winner != 'draw'
                      ? markColor(g.winner!)
                      : null)),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: g.size,
                      crossAxisSpacing: g.size == 3 ? 6 : 2,
                      mainAxisSpacing: g.size == 3 ? 6 : 2,
                    ),
                    itemCount: g.size * g.size,
                    itemBuilder: (context, i) {
                      final mark = g.board[i];
                      return Material(
                        color: g.line.contains(i)
                            ? markColor(mark).withValues(alpha: 0.25)
                            : scheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(g.size == 3 ? 12 : 3),
                          side: g.lastMove == i && !g.finished
                              ? BorderSide(color: scheme.outline)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          key: ValueKey('cell-$i'),
                          onTap: !g.finished && mark.isEmpty
                              ? () => _tap(i)
                              : null,
                          child: Center(
                            child: FractionallySizedBox(
                              widthFactor: 0.6,
                              heightFactor: 0.6,
                              child: FittedBox(
                                child: Text(
                                  mark,
                                  style: TextStyle(
                                    color: markColor(mark),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: g.finished
                  ? FilledButton(
                      onPressed: _again, child: const Text("Yana o'ynash"))
                  : OutlinedButton(
                      onPressed: _again,
                      child: const Text('Qaytadan boshlash')),
            ),
          ),
        ],
      ),
    );
  }
}
