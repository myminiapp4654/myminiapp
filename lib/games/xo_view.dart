import 'package:flutter/material.dart';

import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../widgets/common.dart';

/// X-O o'yini (xona ichida). [room] — serverdagi xona hujjati.
class XoView extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> room;

  const XoView({super.key, required this.roomCode, required this.room});

  @override
  State<XoView> createState() => _XoViewState();
}

class _XoViewState extends State<XoView> {
  final _service = RoomService();

  /// Yuborilgan, lekin hali serverdan tasdiq kelmagan yurish.
  int? _pending;

  Map<String, dynamic> get _game => widget.room['game'] as Map<String, dynamic>;

  @override
  void didUpdateWidget(XoView old) {
    super.didUpdateWidget(old);
    // Server yangi holatni yubordi — kutilayotgan yurish endi taxtada
    final board = _game['board'] as List;
    if (_pending != null && board[_pending!] != '') _pending = null;
  }

  Future<void> _tap(int index) async {
    if (_pending != null) return;
    Telegram.haptic();
    setState(() => _pending = index);
    try {
      await _service.xoMove(widget.roomCode, index);
    } catch (e) {
      if (mounted) {
        setState(() => _pending = null);
        showError(context, e);
      }
    }
  }

  String _name(String uid) =>
      ((widget.room['players'] as Map)[uid] as Map?)?['name'] as String? ??
      'Raqib';

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final me = _service.myUid;
    final size = g['size'] as int;
    final board = List<String>.from(g['board'] as List);
    final xUid = g['x'] as String;
    final oUid = g['o'] as String;
    final myMark = me == xUid ? 'X' : 'O';
    final opponentUid = me == xUid ? oUid : xUid;
    final playing = g['status'] == 'playing';
    final myTurn = playing && g['turn'] == myMark;
    final winner = g['winner'] as String?;
    final line = Set<int>.from(g['line'] as List);
    final lastMove = g['lastMove'] as int?;
    final score = g['score'] as Map;
    final rematch = List<String>.from(g['rematch'] as List);
    final opponentOnline =
        ((widget.room['players'] as Map)[opponentUid] as Map?)?['online'] != false;

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Color markColor(String m) => m == 'X' ? scheme.primary : scheme.tertiary;

    // ---- holat matni ----
    String status;
    if (playing) {
      status = myTurn
          ? 'Sizning navbatingiz ($myMark)'
          : '${_name(opponentUid)} navbati';
    } else if (winner == 'draw') {
      status = 'Durang';
    } else {
      status = winner == myMark ? 'Siz yutdingiz!' : '${_name(opponentUid)} yutdi';
    }

    return Column(
      children: [
        // ---- hisob ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('${_name(xUid)} (X)',
                    style: TextStyle(color: markColor('X')),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${score[xUid] ?? 0} : ${score[oUid] ?? 0}',
                  style: text.titleLarge),
              Expanded(
                child: Text('${_name(oUid)} (O)',
                    textAlign: TextAlign.end,
                    style: TextStyle(color: markColor('O')),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        Text('${g['round']}-raund  •  durang: ${g['draws']}',
            style: text.bodySmall),
        const SizedBox(height: 12),
        Text(status, style: text.titleMedium),
        if (!opponentOnline)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${_name(opponentUid)} aloqada emas',
                style: TextStyle(color: scheme.error)),
          ),
        const SizedBox(height: 12),

        // ---- taxta ----
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: size,
                    crossAxisSpacing: size == 3 ? 6 : 2,
                    mainAxisSpacing: size == 3 ? 6 : 2,
                  ),
                  itemCount: size * size,
                  itemBuilder: (context, i) {
                    final mark = board[i].isNotEmpty
                        ? board[i]
                        : (_pending == i ? myMark : '');
                    final canTap =
                        myTurn && board[i].isEmpty && _pending == null;
                    return Material(
                      color: line.contains(i)
                          ? markColor(mark).withValues(alpha: 0.25)
                          : scheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(size == 3 ? 12 : 3),
                        side: lastMove == i && playing
                            ? BorderSide(color: scheme.outline)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: canTap ? () => _tap(i) : null,
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.6,
                            heightFactor: 0.6,
                            child: FittedBox(
                              child: Text(
                                mark,
                                style: TextStyle(
                                  color: markColor(mark).withValues(
                                      alpha: _pending == i ? 0.5 : 1),
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

        // ---- tugmalar ----
        Padding(
          padding: const EdgeInsets.all(16),
          child: playing
              ? OutlinedButton(
                  onPressed: () => runAction(
                      context, () => _service.endGame(widget.roomCode)),
                  child: const Text("O'yinni tugatish"),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (rematch.contains(opponentUid) && !rematch.contains(me))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text("${_name(opponentUid)} yana o'ynamoqchi",
                            textAlign: TextAlign.center),
                      ),
                    FilledButton(
                      onPressed: rematch.contains(me)
                          ? null
                          : () => runAction(context,
                              () => _service.xoRematch(widget.roomCode)),
                      child: Text(rematch.contains(me)
                          ? 'Raqib kutilmoqda...'
                          : "Yana o'ynash"),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => runAction(
                          context, () => _service.endGame(widget.roomCode)),
                      child: const Text('Xonaga qaytish'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
