import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../services/checkers_service.dart';
import '../widgets/common.dart';

class CheckersScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;

  const CheckersScreen(
      {super.key, required this.roomCode, required this.isCreator});

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  final _service = CheckersService();
  int? _selected;

  Future<void> _leave(String status) async {
    final nav = Navigator.of(context);
    if (status != 'finished' && widget.isCreator) {
      await _service.deleteRoom(widget.roomCode).catchError((_) {});
    }
    nav.pop();
  }

  void _onTap(int index, List<String> board, String myColor, int? selected,
      List<Map<String, int>> moves) {
    final move = moves.where((m) => m['to'] == index).firstOrNull;
    if (move != null && selected != null) {
      setState(() => _selected = null);
      runAction(context,
          () => _service.makeMove(widget.roomCode, selected, move));
      return;
    }
    final piece = board[index];
    setState(() {
      _selected =
          piece.isNotEmpty && piece.toLowerCase() == myColor ? index : null;
    });
  }

  String _statusText(String status, String? winner, bool myTurn, String me) {
    if (status == 'waiting') return 'Raqib kutilmoqda';
    if (status == 'finished') return winner == me ? 'Siz yutdingiz' : 'Raqib yutdi';
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
        final chainJump = (data['chainJump'] as int?) ?? -1;
        final lastMove = data['lastMove'] as Map?;

        final me = _service.myUid == p1['uid'] ? 'w' : 'b';
        final myTurn = turn == me && status == 'playing';

        // Zanjirli urishda dona avtomatik tanlanadi
        final selected = !myTurn
            ? null
            : (chainJump >= 0 ? chainJump : _selected);
        final moves = selected == null
            ? const <Map<String, int>>[]
            : _service.validMoves(board, selected, chainJump);
        final targets = moves.map((m) => m['to']).toSet();

        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _leave(status)),
            title: const Text('Shashka'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('${p1['name']} (oq)  —  ${p2?['name'] ?? '...'} (qora)'),
                const SizedBox(height: 8),
                Text(_statusText(status, data['winner'] as String?, myTurn, me)),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8),
                        itemCount: 64,
                        itemBuilder: (context, i) {
                          final dark = (i ~/ 8 + i % 8) % 2 == 1;
                          final piece = board[i];
                          Color bg = dark ? Colors.brown.shade700 : Colors.brown.shade200;
                          if (i == selected) {
                            bg = scheme.primary;
                          } else if (targets.contains(i)) {
                            bg = scheme.primaryContainer;
                          } else if (lastMove != null &&
                              (lastMove['from'] == i || lastMove['to'] == i)) {
                            bg = Colors.brown.shade500;
                          }
                          return GestureDetector(
                            onTap: dark && myTurn
                                ? () => _onTap(i, board, me, selected, moves)
                                : null,
                            child: Container(
                              color: bg,
                              padding: const EdgeInsets.all(5),
                              child: piece.isEmpty
                                  ? null
                                  : Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: piece.toLowerCase() == 'w'
                                            ? Colors.white
                                            : Colors.black,
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: piece == 'W' || piece == 'B'
                                          ? const FittedBox(
                                              child: Icon(Icons.star,
                                                  color: Colors.amber))
                                          : null,
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
