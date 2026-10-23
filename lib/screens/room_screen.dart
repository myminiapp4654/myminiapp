import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/xo_view.dart';
import '../net/server_client.dart';
import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../widgets/common.dart';

/// O'yin nomi (taklif matnlari uchun).
String gameTitle(Map invite) {
  final options = invite['options'] as Map? ?? {};
  return switch (invite['game']) {
    'xo' => 'X-O ${options['size']}×${options['size']}',
    _ => "O'yin",
  };
}

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const RoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _service = RoomService();

  /// Oxirgi ko'rsatilgan voqea (chiqib ketdi, o'yinni tugatdi).
  int? _lastEventAt;
  bool _inGame = false;

  Future<void> _leaveRoom() async {
    final nav = Navigator.of(context);
    try {
      await _service.leaveRoom(widget.roomCode);
    } catch (_) {}
    nav.pop();
  }

  /// Orqaga: o'yin ketayotgan bo'lsa — so'raymiz, aks holda xonadan chiqamiz.
  Future<void> _onBack() async {
    if (!_inGame) {
      await _leaveRoom();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'yindan chiqasizmi?"),
        content: const Text("O'yin tugaydi, ikkalangiz xonaga qaytasiz."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Yo'q")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ha')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runAction(context, () => _service.endGame(widget.roomCode));
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kod nusxalandi')));
  }

  /// Telegram'da do'st tanlash oynasini ochadi.
  void _inviteFriend() {
    final link = ServerClient.instance.roomInviteLink(widget.roomCode);
    Telegram.openLink('https://t.me/share/url'
        '?url=${Uri.encodeComponent(link)}'
        '&text=${Uri.encodeComponent("Keling, birga o'ynaymiz!")}');
  }

  Future<void> _proposeXo() async {
    final size = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('X-O'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 3),
            child: const ListTile(
              title: Text('3 × 3'),
              subtitle: Text('3 tasi bir qatorda — yutadi'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 10),
            child: const ListTile(
              title: Text('10 × 10'),
              subtitle: Text('5 tasi bir qatorda — yutadi'),
            ),
          ),
        ],
      ),
    );
    if (size == null || !mounted) return;
    await runAction(
        context, () => _service.invite(widget.roomCode, 'xo', {'size': size}));
  }

  /// Raqib chiqib ketsa yoki o'yinni tugatsa — xabar.
  void _showEvent(Map<String, dynamic> room) {
    final event = room['event'] as Map?;
    final at = event?['at'] as int?;
    if (_lastEventAt == null) {
      _lastEventAt = at ?? 0; // ochilgandagi eski voqeani ko'rsatmaymiz
      return;
    }
    if (at == null || at == _lastEventAt) return;
    _lastEventAt = at;
    if (event!['uid'] == _service.myUid) return;
    final text = switch (event['type']) {
      'left' => '${event['name']} xonadan chiqib ketdi',
      'ended' => "${event['name']} o'yinni tugatdi",
      _ => null,
    };
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.roomStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingScreen();
        if (!snapshot.data!.exists) return const ClosedScreen();

        final room = snapshot.data!.data()!;
        _showEvent(room);
        final game = room['game'] as Map<String, dynamic>?;
        _inGame = game != null && game['status'] == 'playing';

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBack();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: _onBack),
              title: Text(game != null ? 'X-O' : 'Xona ${widget.roomCode}'),
              actions: [
                if (game == null)
                  IconButton(icon: const Icon(Icons.copy), onPressed: _copyCode),
              ],
            ),
            body: game != null && game['type'] == 'xo'
                ? XoView(roomCode: widget.roomCode, room: room)
                : _buildLobby(room),
          ),
        );
      },
    );
  }

  Widget _buildLobby(Map<String, dynamic> room) {
    final players = room['players'] as Map<String, dynamic>;
    final hostUid = room['host'] as String;
    final invite = room['invite'] as Map<String, dynamic>?;
    final me = _service.myUid;
    final scheme = Theme.of(context).colorScheme;

    final children = <Widget>[
      for (final e in players.entries)
        ListTile(
          leading: Icon(Icons.circle,
              size: 12,
              color: (e.value as Map)['online'] == false
                  ? scheme.outline
                  : Colors.green),
          title: Text((e.value as Map)['name'] as String),
          subtitle: Text([
            if (e.key == hostUid) "Xo'jayin",
            if ((e.value as Map)['online'] == false) 'aloqada emas',
          ].join(' • ')),
          trailing: e.key == me ? const Text('Siz') : null,
        ),
      const Divider(),
    ];

    if (players.length < 2) {
      children.addAll([
        const Text("Ikkinchi o'yinchi kutilmoqda"),
        const SizedBox(height: 12),
        if (Telegram.isAvailable)
          FilledButton.icon(
            onPressed: _inviteFriend,
            icon: const Icon(Icons.send),
            label: const Text("Do'stni chaqirish"),
          )
        else
          Text('Kodni yuboring: ${widget.roomCode}'),
      ]);
    } else if (invite == null) {
      children.addAll([
        const Text("O'yin tanlang"),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.grid_3x3),
            title: const Text('X-O'),
            subtitle: const Text('Krestik-nolik'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _proposeXo,
          ),
        ),
      ]);
    } else if (invite['from'] == me) {
      children.addAll([
        Text('${gameTitle(invite)} — raqib javobi kutilmoqda'),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () =>
              runAction(context, () => _service.decline(widget.roomCode)),
          child: const Text('Bekor qilish'),
        ),
      ]);
    } else {
      final from = (players[invite['from']] as Map?)?['name'] ?? 'Raqib';
      children.addAll([
        Text('$from ${gameTitle(invite)} o\'ynashni taklif qilyapti'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    runAction(context, () => _service.accept(widget.roomCode)),
                child: const Text('Qabul qilish'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    runAction(context, () => _service.decline(widget.roomCode)),
                child: const Text('Rad etish'),
              ),
            ),
          ],
        ),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}
