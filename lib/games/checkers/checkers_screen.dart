import 'package:flutter/material.dart';

import 'checkers_game.dart';

/// Shashka: bitta telefonda ikki kishi. Oq pastda, birinchi yuradi.
class CheckersScreen extends StatefulWidget {
  const CheckersScreen({super.key});

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  final _game = CheckersGame();
  int? _selected;

  static String _colorName(String c) => c == 'w' ? 'Oq' : 'Qora';

  void _tap(int i, List<CheckersMove> moves) {
    final from = _game.chain ?? _selected;
    if (from != null && moves.any((m) => m.from == from && m.to == i)) {
      setState(() {
        _game.play(from, i);
        _selected = null;
      });
      return;
    }
    if (_game.chain != null) return; // zanjirli urishda boshqa dona tanlanmaydi
    setState(() {
      _selected = moves.any((m) => m.from == i) ? i : null;
    });
  }

  void _newRound() => setState(() {
        _game.newRound();
        _selected = null;
      });

  Future<void> _offerDraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Durang?'),
        content: const Text("Ikkalangiz rozi bo'lsangiz, raund durang bilan tugaydi."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Yo'q")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ha, durang')),
        ],
      ),
    );
    if (ok == true) setState(_game.agreeDraw);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final moves = g.legalMoves();
    final selected = g.chain ?? _selected;
    final targets = {
      for (final m in moves)
        if (m.from == selected) m.to,
    };
    final movable = {for (final m in moves) m.from};
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final String status;
    if (g.winner == 'draw') {
      status = 'Durang';
    } else if (g.finished) {
      status = '${_colorName(g.winner!)} yutdi!';
    } else if (g.chain != null) {
      status = '${_colorName(g.turn)}: urishni davom ettiring';
    } else if (g.mustCapture) {
      status = '${_colorName(g.turn)} navbati — urish majburiy';
    } else {
      status = '${_colorName(g.turn)} navbati';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Shashka')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text("Oq  ${g.score['w']} : ${g.score['b']}  Qora",
              style: text.titleLarge),
          Text('${g.round}-raund  •  durang: ${g.draws}  •  '
              'donalar: ${g.count('w')} / ${g.count('b')}',
              style: text.bodySmall),
          const SizedBox(height: 12),
          Text(status, style: text.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (context, i) {
                      final dark = (i ~/ 8 + i % 8).isOdd;
                      final piece = g.board[i];

                      Color bg = dark
                          ? const Color(0xFF8B5A2B)
                          : const Color(0xFFEED9B6);
                      if (i == selected) {
                        bg = scheme.primary;
                      } else if (targets.contains(i)) {
                        bg = scheme.primary.withValues(alpha: 0.45);
                      } else if (i == g.lastFrom || i == g.lastTo) {
                        bg = const Color(0xFFB5823F);
                      }

                      return GestureDetector(
                        key: ValueKey('sq-$i'),
                        onTap: dark && !g.finished ? () => _tap(i, moves) : null,
                        child: Container(
                          color: bg,
                          padding: const EdgeInsets.all(4),
                          child: piece.isEmpty
                              ? null
                              : _Piece(
                                  piece: piece,
                                  // urilgan, hali olinmagan dona xira ko'rinadi
                                  faded: g.captured.contains(i),
                                  canMove: !g.finished &&
                                      g.chain == null &&
                                      movable.contains(i),
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
            child: g.finished
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _newRound,
                        child: const Text("Yana o'ynash")),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                            onPressed: _offerDraw,
                            child: const Text('Durang')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                            onPressed: _newRound,
                            child: const Text('Qaytadan')),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  final String piece;
  final bool faded;
  final bool canMove;

  const _Piece({required this.piece, required this.faded, required this.canMove});

  @override
  Widget build(BuildContext context) {
    final white = CheckersGame.colorOf(piece) == 'w';
    return Opacity(
      opacity: faded ? 0.35 : 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: white ? const Color(0xFFF5F5F5) : const Color(0xFF222222),
          border: Border.all(
            color: canMove ? Colors.amber : Colors.black45,
            width: canMove ? 2.5 : 1.5,
          ),
        ),
        child: CheckersGame.isKing(piece)
            ? FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.star,
                      color: white ? Colors.black87 : Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}
