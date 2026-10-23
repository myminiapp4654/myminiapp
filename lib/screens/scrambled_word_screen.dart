import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../services/scrambled_word_service.dart';
import '../widgets/common.dart';

/// Harflar: aralashtirilgan harflardan so'zni birga yig'ish.
/// Harfni bossangiz, u keyingi bo'sh joyga qo'yiladi (to'g'ri bo'lsa).
class ScrambledWordScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const ScrambledWordScreen(
      {super.key, required this.roomCode, required this.isHost});

  @override
  State<ScrambledWordScreen> createState() => _ScrambledWordScreenState();
}

class _ScrambledWordScreenState extends State<ScrambledWordScreen> {
  final _service = ScrambledWordService();

  Future<void> _leave(String status) async {
    final nav = Navigator.of(context);
    if (status != 'finished' && widget.isHost) {
      await _service.deleteRoom(widget.roomCode).catchError((_) {});
    }
    nav.pop();
  }

  void _place(String letter, String word, List<String> slots) {
    final slot = slots.indexWhere((s) => s.isEmpty);
    if (slot < 0) return;
    if (word[slot] != letter) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text("Noto'g'ri harf"), duration: Duration(seconds: 1)));
      return;
    }
    runAction(
        context, () => _service.placeLetter(widget.roomCode, slot, letter));
  }

  /// Hali ishlatilmagan harflar (bir xil harflar sonini hisobga olib).
  List<bool> _available(List<String> letters, List<String> slots) {
    final used = <String, int>{};
    for (final s in slots) {
      if (s.isNotEmpty) used[s] = (used[s] ?? 0) + 1;
    }
    final result = <bool>[];
    for (final l in letters) {
      final u = used[l] ?? 0;
      if (u > 0) {
        used[l] = u - 1;
        result.add(false);
      } else {
        result.add(true);
      }
    }
    return result;
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
        final word = data['word'] as String;
        final letters = List<String>.from(data['letters'] as List);
        final slots = List<String>.from(data['slots'] as List);
        final available = _available(letters, slots);

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => _leave(status)),
            title: const Text('Harflar'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: status == 'waiting'
                ? const Center(child: Text('Raqib kutilmoqda'))
                : ListView(
                    children: [
                      Text('Yordam: ${data['hint']}'),
                      const SizedBox(height: 16),
                      Text(
                        slots.map((s) => s.isEmpty ? '_' : s).join(' '),
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (status == 'playing')
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var i = 0; i < letters.length; i++)
                              SizedBox(
                                width: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  onPressed: available[i]
                                      ? () => _place(letters[i], word, slots)
                                      : null,
                                  child: Text(letters[i]),
                                ),
                              ),
                          ],
                        ),
                      if (status == 'finished') ...[
                        const Text('Topdingiz!', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        if (widget.isHost)
                          FilledButton(
                            onPressed: () => runAction(context,
                                () => _service.playAgain(widget.roomCode)),
                            child: const Text("Yangi so'z"),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Xonaga qaytish'),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}
