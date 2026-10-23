import 'package:flutter/material.dart';
import 'package:oyinim_core/oyinim_core.dart';

import '../net/server_client.dart';
import '../services/stars_service.dart';
import '../services/word_puzzle_service.dart';
import '../widgets/common.dart';

/// So'z topish: ikkalasi navbat bilan harf tanlab 3 ta so'zni ochadi.
class WordPuzzleScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const WordPuzzleScreen(
      {super.key, required this.roomCode, required this.isHost});

  @override
  State<WordPuzzleScreen> createState() => _WordPuzzleScreenState();
}

class _WordPuzzleScreenState extends State<WordPuzzleScreen> {
  final _service = WordPuzzleService();
  final _stars = StarsService();

  Future<void> _leave(String status) async {
    final nav = Navigator.of(context);
    if (widget.isHost && status != 'finished') {
      await _service.deleteRoom(widget.roomCode).catchError((_) {});
    }
    nav.pop();
  }

  Future<void> _reveal() async {
    try {
      final ok = await _service.revealWithStar(widget.roomCode);
      if (!ok && mounted) {
        showError(context, ServerException('Yulduzlar yetarli emas'));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        if (!snapshot.data!.exists) return const ClosedScreen();

        final data = snapshot.data!.data()!;
        final status = data['status'] as String;
        final level = (data['level'] as int?) ?? 0;

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _leave(status)),
            title: Text("So'z topish — ${level + 1}-daraja"),
            actions: [
              StreamBuilder<int>(
                stream: _stars.starsStream(),
                builder: (_, s) => TextButton(
                  onPressed: status == 'playing' ? _reveal : null,
                  child: Text('★ ${s.data ?? 0}'),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: status == 'waiting'
                ? const Center(child: Text('Raqib kutilmoqda'))
                : _buildGame(data, status, level),
          ),
        );
      },
    );
  }

  Widget _buildGame(Map<String, dynamic> data, String status, int level) {
    final words = (data['puzzle']['words'] as List).cast<Map>();
    final tiles = List<String>.from(data['letterTiles'] as List);
    final revealed = List<String>.from(data['revealedLetters'] as List);
    final wrong = List<String>.from(data['wrongLetters'] as List);
    final p1 = data['player1'] as Map;
    final p2 = data['player2'] as Map?;
    final turn = data['currentTurn'] as String;
    final myTurn = turn == _service.myUid && status == 'playing';
    final result = data['result'] as String?;
    final finished = status == 'finished';
    final turnName = turn == p1['uid'] ? p1['name'] : p2?['name'];

    return ListView(
      children: [
        Text(finished
            ? (result == 'win' ? 'Topdingiz!' : 'Yutqazdingiz')
            : myTurn
                ? 'Sizning navbatingiz'
                : '$turnName navbati'),
        Text('Xatolar: ${wrong.length}/${WordPuzzleRules.maxWrong}'),
        const SizedBox(height: 16),
        for (final w in words) ...[
          Text('${w['emoji'] ?? ''} ${w['hint']}'),
          const SizedBox(height: 4),
          Text(
            (w['word'] as String)
                .split('')
                .map((l) => finished || revealed.contains(l) ? l : '_')
                .join(' '),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
        ],
        if (!finished)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tiles)
                SizedBox(
                  width: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: revealed.contains(t)
                          ? Colors.green.withValues(alpha: 0.3)
                          : wrong.contains(t)
                              ? Colors.red.withValues(alpha: 0.3)
                              : null,
                    ),
                    onPressed:
                        myTurn && !revealed.contains(t) && !wrong.contains(t)
                            ? () => runAction(context,
                                () => _service.pickLetter(widget.roomCode, t))
                            : null,
                    child: Text(t),
                  ),
                ),
            ],
          ),
        if (finished) ...[
          const SizedBox(height: 8),
          if (widget.isHost)
            FilledButton(
              onPressed: () => runAction(
                context,
                () => _service.nextLevel(
                    widget.roomCode, result == 'win' ? level + 1 : level),
              ),
              child: Text(result == 'win' ? 'Keyingi daraja' : 'Qayta urinish'),
            )
          else
            const Text("Xo'jayin davom ettiradi"),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Xonaga qaytish'),
          ),
        ],
      ],
    );
  }
}
