import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../services/game_service.dart';
import '../widgets/common.dart';

/// X-O: 5 tasini bir qatorga terish, har bir qator — 1 ochko.
class TicTacToeScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;

  const TicTacToeScreen(
      {super.key, required this.roomCode, required this.isCreator});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  final _service = GameService();

  Future<void> _leave(String status) async {
    final nav = Navigator.of(context);
    if (status != 'finished' && widget.isCreator) {
      await _service.deleteRoom(widget.roomCode).catchError((_) {});
    }
    nav.pop();
  }

  String _statusText(String status, String? winner, bool myTurn, String me) {
    if (status == 'waiting') return 'Raqib kutilmoqda';
    if (status == 'finished') {
      if (winner == 'draw') return 'Durang';
      return winner == me ? 'Siz yutdingiz' : 'Raqib yutdi';
    }
    return myTurn ? 'Sizning navbatingiz' : 'Raqib navbati';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        if (!snapshot.data!.exists) return const ClosedScreen();

        final data = snapshot.data!.data()!;
        final board = List<String>.from(data['board'] as List);
        final status = data['status'] as String;
        final turn = data['currentTurn'] as String;
        final p1 = data['player1'] as Map;
        final p2 = data['player2'] as Map?;
        final size = (data['gridSize'] as int?) ?? 10;
        final scoreX = (data['scoreX'] as int?) ?? 0;
        final scoreO = (data['scoreO'] as int?) ?? 0;
        final winning = Set<int>.from(data['winningCells'] as List? ?? []);

        final me = _service.myUid == p1['uid'] ? 'X' : 'O';
        final myTurn = turn == me && status == 'playing';
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _leave(status)),
            title: const Text('X-O'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('${p1['name']} (X): $scoreX   —   '
                    '${p2?['name'] ?? '...'} (O): $scoreO'),
                const SizedBox(height: 8),
                Text(_statusText(status, data['winner'] as String?, myTurn, me)),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: size),
                        itemCount: size * size,
                        itemBuilder: (context, i) {
                          final cell = board[i];
                          return InkWell(
                            onTap: myTurn && cell.isEmpty
                                ? () => runAction(context,
                                    () => _service.makeMove(widget.roomCode, i))
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: winning.contains(i)
                                    ? scheme.primaryContainer
                                    : null,
                                border: Border.all(
                                    color: scheme.outlineVariant, width: 0.5),
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                child: Text(
                                  cell,
                                  style: TextStyle(
                                    color: cell == 'X'
                                        ? scheme.primary
                                        : scheme.error,
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
                if (status == 'finished')
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Xonaga qaytish'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
