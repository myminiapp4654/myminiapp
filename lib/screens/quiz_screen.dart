import 'dart:async';

import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../services/quiz_service.dart';
import '../widgets/common.dart';

class QuizScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const QuizScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _seconds = 15;

  final _service = QuizService();
  Timer? _timer;
  int _shownQuestion = -1;
  int _timeLeft = _seconds;
  int? _myAnswer;
  bool _revealed = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Yangi savol kelganda vaqtni qaytadan boshlaydi.
  void _onQuestion(int index) {
    if (index == _shownQuestion) return;
    _timer?.cancel();
    setState(() {
      _shownQuestion = index;
      _timeLeft = _seconds;
      _myAnswer = null;
      _revealed = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _timeLeft--);
      if (_timeLeft > 0) return;
      t.cancel();
      setState(() => _revealed = true);
      // Vaqt tugagach, 3 soniyadan keyin xo'jayin keyingi savolga o'tkazadi
      if (widget.isHost) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _service.nextQuestion(widget.roomCode, index).catchError((_) {});
          }
        });
      }
    });
  }

  void _answer(int index) {
    if (_myAnswer != null || _revealed) return;
    setState(() => _myAnswer = index);
    runAction(context, () => _service.submitAnswer(widget.roomCode, index));
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
        final questions = data['questions'] as List;
        final current = data['currentQuestion'] as int;
        final players = data['players'] as Map<String, dynamic>;

        if (status == 'playing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onQuestion(current);
          });
        }

        final Widget body;
        if (status == 'waiting') {
          body = _buildWaiting(players);
        } else if (status == 'finished') {
          body = _buildResults(players);
        } else if (current < 0 || current >= questions.length) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          body = _buildQuestion(
              questions[current] as Map, current, questions.length, players);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Viktorina')),
          body: Padding(padding: const EdgeInsets.all(16), child: body),
        );
      },
    );
  }

  Widget _buildWaiting(Map<String, dynamic> players) {
    return ListView(
      children: [
        for (final p in players.values) ListTile(title: Text((p as Map)['name'] as String)),
        const SizedBox(height: 16),
        if (widget.isHost)
          FilledButton(
            onPressed: () =>
                runAction(context, () => _service.startQuiz(widget.roomCode)),
            child: const Text('Boshlash'),
          )
        else
          const Text("Xo'jayin boshlashini kuting"),
      ],
    );
  }

  Widget _buildQuestion(
      Map q, int index, int total, Map<String, dynamic> players) {
    final options = List<String>.from(q['o'] as List);
    final correct = q['c'] as int;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Text('Savol ${index + 1}/$total   •   $_timeLeft s'),
        const SizedBox(height: 16),
        Text(q['q'] as String, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _revealed && i == correct
                    ? Colors.green.withValues(alpha: 0.3)
                    : _myAnswer == i
                        ? scheme.primaryContainer
                        : null,
              ),
              onPressed: _myAnswer == null && !_revealed ? () => _answer(i) : null,
              child: Text(options[i]),
            ),
          ),
        const SizedBox(height: 16),
        for (final p in players.values)
          Text('${(p as Map)['name']}: ${p['score']}'),
      ],
    );
  }

  Widget _buildResults(Map<String, dynamic> players) {
    final list = players.values.cast<Map>().toList()
      ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return ListView(
      children: [
        const Text('Natijalar'),
        for (var i = 0; i < list.length; i++)
          ListTile(
            leading: Text('${i + 1}'),
            title: Text(list[i]['name'] as String),
            trailing: Text('${list[i]['score']}'),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Xonaga qaytish'),
        ),
      ],
    );
  }
}
