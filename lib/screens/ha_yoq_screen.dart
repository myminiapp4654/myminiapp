import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../services/ha_yoq_service.dart';
import '../widgets/common.dart';

/// Ha / Yo'q: biri savol beradi, ikkinchisi faqat "ha" yoki "yo'q" deydi.
class HaYoqScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const HaYoqScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<HaYoqScreen> createState() => _HaYoqScreenState();
}

class _HaYoqScreenState extends State<HaYoqScreen> {
  final _service = HaYoqService();
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _questionController.text.trim();
    if (q.isEmpty) return;
    await runAction(context, () => _service.askQuestion(widget.roomCode, q));
    _questionController.clear();
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

        final Widget body = switch (status) {
          'waiting' => _buildWaiting(data),
          'finished' => _buildResults(data),
          _ => _buildPlaying(data),
        };

        return Scaffold(
          appBar: AppBar(title: const Text("Ha / Yo'q")),
          body: Padding(padding: const EdgeInsets.all(16), child: body),
        );
      },
    );
  }

  Widget _buildWaiting(Map<String, dynamic> data) {
    final players = data['players'] as Map<String, dynamic>;
    return ListView(
      children: [
        for (final p in players.values)
          ListTile(title: Text((p as Map)['name'] as String)),
        const SizedBox(height: 16),
        if (widget.isHost)
          FilledButton(
            onPressed: () =>
                runAction(context, () => _service.startGame(widget.roomCode)),
            child: const Text('Boshlash'),
          )
        else
          const Text("Xo'jayin boshlashini kuting"),
      ],
    );
  }

  Widget _buildPlaying(Map<String, dynamic> data) {
    final order = List<String>.from(data['playerOrder'] as List);
    final players = data['players'] as Map;
    final askerUid = order[data['currentAskerIndex'] as int];
    final answererUid = order[data['currentAnswererIndex'] as int];
    final askerName = players[askerUid]['name'] as String;
    final answererName = players[answererUid]['name'] as String;
    final question = data['pendingQuestion'] as String?;
    final asked = data['askedCount'] as int;
    final total = data['questionCount'] as int;
    final myUid = _service.myUid;

    final children = <Widget>[
      Text('$askerName → $answererName   •   Savol ${asked + 1}/$total'),
      const SizedBox(height: 16),
    ];

    if (question == null) {
      if (myUid == askerUid) {
        children.addAll([
          Text('$answererName ga savol bering'),
          const SizedBox(height: 8),
          TextField(
            controller: _questionController,
            maxLength: 300,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => _ask(),
          ),
          FilledButton(onPressed: _ask, child: const Text('Yuborish')),
        ]);
      } else {
        children.add(Text('$askerName savol yozyapti...'));
      }
    } else {
      children.addAll([
        Text(question, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
      ]);
      if (myUid == answererUid) {
        children.add(Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => runAction(context,
                    () => _service.answerQuestion(widget.roomCode, 'ha')),
                child: const Text('Ha'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => runAction(context,
                    () => _service.answerQuestion(widget.roomCode, 'yoq')),
                child: const Text("Yo'q"),
              ),
            ),
          ],
        ));
      } else {
        children.add(Text('$answererName javob beryapti...'));
      }
    }

    return ListView(children: children);
  }

  Widget _buildResults(Map<String, dynamic> data) {
    final log = (data['log'] as List).cast<Map>();
    return ListView(
      children: [
        const Text('Natijalar'),
        for (final e in log)
          ListTile(
            title: Text(e['question'] as String),
            subtitle: Text('${e['askerName']} → ${e['answererName']}'),
            trailing: Text(e['answer'] == 'ha' ? 'Ha' : "Yo'q"),
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
