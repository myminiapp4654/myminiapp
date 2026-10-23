import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/server_client.dart';
import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../widgets/common.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const RoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _roomService = RoomService();

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
                  trailing:
                      e.key == _roomService.myUid ? const Text('Siz') : null,
                ),
              const Divider(),
              if (players.length < 2) ...[
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
              ],
            ],
          ),
        );
      },
    );
  }
}
