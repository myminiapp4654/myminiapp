import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/server_client.dart';
import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../widgets/common.dart';
import 'checkers_screen.dart';
import 'ha_yoq_screen.dart';
import 'quiz_screen.dart';
import 'scrambled_word_screen.dart';
import 'tictactoe_screen.dart';
import 'word_puzzle_screen.dart';

/// O'yin turlari: id -> nomi.
const kGameNames = {
  'tictactoe': 'X-O',
  'checkers': 'Shashka',
  'quiz': 'Viktorina',
  'hayoq': "Ha / Yo'q",
  'wordpuzzle': "So'z topish",
  'scramble': 'Harflar',
};

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const RoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _roomService = RoomService();

  bool _navigating = false;
  bool _busy = false;
  final _visitedGameCodes = <String>{};

  Future<void> _leave() async {
    final nav = Navigator.of(context);
    try {
      await _roomService.leaveRoom(widget.roomCode);
    } catch (_) {}
    nav.pop();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kod nusxalandi')));
  }

  /// Telegram'da do'st tanlash oynasini ochadi.
  void _invite() {
    final link = ServerClient.instance.roomInviteLink(widget.roomCode);
    Telegram.openLink('https://t.me/share/url'
        '?url=${Uri.encodeComponent(link)}'
        '&text=${Uri.encodeComponent("Keling, birga o'ynaymiz!")}');
  }

  Future<void> _selectGame(String game) async {
    Map<String, dynamic>? options;
    if (game == 'tictactoe') {
      final size = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text("Taxta o'lchami"),
          children: [
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 10),
                child: const Text('10 × 10')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 12),
                child: const Text('12 × 12')),
          ],
        ),
      );
      if (size == null) return;
      options = {'gridSize': size};
    }
    if (!mounted) return;
    setState(() => _busy = true);
    await runAction(context,
        () => _roomService.proposeGame(widget.roomCode, game, options: options));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openGame(Map invite, bool amIHost) async {
    final game = invite['game'] as String;
    final code = invite['gameCode'] as String;
    _visitedGameCodes.add(code);

    final Widget screen = switch (game) {
      'tictactoe' => TicTacToeScreen(roomCode: code, isCreator: amIHost),
      'checkers' => CheckersScreen(roomCode: code, isCreator: amIHost),
      'quiz' => QuizScreen(roomCode: code, isHost: amIHost),
      'hayoq' => HaYoqScreen(roomCode: code, isHost: amIHost),
      'wordpuzzle' => WordPuzzleScreen(roomCode: code, isHost: amIHost),
      'scramble' => ScrambledWordScreen(roomCode: code, isHost: amIHost),
      _ => const SizedBox(),
    };
    if (screen is SizedBox || !mounted) {
      _navigating = false;
      return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (mounted) {
      _navigating = false;
      if (amIHost) {
        await _roomService.resetAfterGame(widget.roomCode).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _roomService.roomStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        if (!snapshot.data!.exists) return const ClosedScreen();

        final data = snapshot.data!.data()!;
        final players = data['players'] as Map<String, dynamic>;
        final hostUid = data['host'] as String;
        final amIHost = _roomService.myUid == hostUid;
        final invite = data['gameInvite'] as Map<String, dynamic>?;

        // Taklif qabul qilinsa — ikkalasi ham o'yinga o'tadi
        if (invite != null &&
            invite['response'] == 'accepted' &&
            !_navigating &&
            !_visitedGameCodes.contains(invite['gameCode'])) {
          _navigating = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _openGame(invite, amIHost));
        }

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _leave),
            title: Text('Xona ${widget.roomCode}'),
            actions: [
              IconButton(icon: const Icon(Icons.copy), onPressed: _copyCode),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final e in players.entries)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text((e.value as Map)['name'] as String),
                  subtitle: Text(e.key == hostUid ? "Xo'jayin" : 'Mehmon'),
                  trailing: e.key == _roomService.myUid ? const Text('Siz') : null,
                ),
              const Divider(),
              ..._buildContent(players, amIHost, invite),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildContent(
      Map<String, dynamic> players, bool amIHost, Map<String, dynamic>? invite) {
    if (players.length < 2) {
      return [
        const Text("Ikkinchi o'yinchi kutilmoqda"),
        const SizedBox(height: 12),
        if (Telegram.isAvailable)
          FilledButton.icon(
            onPressed: _invite,
            icon: const Icon(Icons.send),
            label: const Text("Do'stni chaqirish"),
          )
        else
          Text('Kodni yuboring: ${widget.roomCode}'),
      ];
    }

    if (invite != null && invite['response'] == null) {
      final gameName = kGameNames[invite['game']] ?? '';
      if (amIHost) {
        return [
          Text('$gameName — javob kutilmoqda'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => runAction(
                context, () => _roomService.rejectInvite(widget.roomCode)),
            child: const Text('Bekor qilish'),
          ),
        ];
      }
      return [
        Text("$gameName o'ynaysizmi?"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => runAction(
                    context, () => _roomService.acceptInvite(widget.roomCode)),
                child: const Text('Ha'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => runAction(
                    context, () => _roomService.rejectInvite(widget.roomCode)),
                child: const Text("Yo'q"),
              ),
            ),
          ],
        ),
      ];
    }

    if (!amIHost) return [const Text("Xo'jayin o'yin tanlayapti...")];

    return [
      const Text("O'yin tanlang"),
      const SizedBox(height: 8),
      for (final g in kGameNames.entries)
        ListTile(
          title: Text(g.value),
          trailing: const Icon(Icons.chevron_right),
          enabled: !_busy,
          onTap: () => _selectGame(g.key),
        ),
    ];
  }
}
