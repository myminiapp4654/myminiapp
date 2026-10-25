import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/checkers/checkers_screen.dart';
import '../games/chess/chess_screen.dart';
import '../net/online_match.dart';
import '../net/server_client.dart';
import '../telegram/telegram.dart';
import '../ui/kit.dart';

/// Taklif havolasidagi belgi: `play_<KOD>`.
const kPlayLinkPrefix = 'play_';

/// Onlayn o'yin turi: nomi, ranglari va o'yin ekrani.
class OnlineGameKind {
  final String title;
  final GamePalette palette;
  final int maxPlayers;
  final Widget Function(OnlineMatch match) build;
  const OnlineGameKind(this.title, this.palette, this.maxPlayers, this.build);
}

final kOnlineGames = <String, OnlineGameKind>{
  'chess': OnlineGameKind('Shaxmat', GamePalette.chess, 2, (m) => ChessScreen(online: m)),
  'checkers': OnlineGameKind('Shashka', GamePalette.checkers, 2, (m) => CheckersScreen(online: m)),
};

/// Onlayn xona: kutish (o'rinlar, taklif, "Tayyorman") → o'yin → yana kutish.
class OnlineRoomScreen extends StatefulWidget {
  final String code;
  const OnlineRoomScreen({super.key, required this.code});

  /// Admin: [game] uchun yangi xona ochib, unga o'tadi.
  static Future<void> create(BuildContext context, String game) async {
    try {
      final r = await ServerClient.instance.call<Map>('play.create', {'game': game});
      final code = r?['code'] as String?;
      if (code == null || !context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnlineRoomScreen(code: code)));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  final _server = ServerClient.instance;
  StreamSubscription<Doc>? _sub;
  Map<String, dynamic>? _room;
  String? _error;

  /// Joriy raund (o'yin boshlanganda yaratiladi).
  OnlineMatch? _match;
  int? _matchRound;
  final _moves = ValueNotifier<List<String>>(const []);
  final _left = ValueNotifier<String?>(null);

  String get _uid => _server.myUid;
  String get _code => widget.code;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      await _server.call('play.join', {'code': _code});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    }
    _sub = _server.watch('play/$_code').listen(_onRoom);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _server.call('play.leave', {'code': _code}).catchError((_) => null);
    _moves.dispose();
    _left.dispose();
    super.dispose();
  }

  List<(String, String)> _players(Map<String, dynamic> d) {
    final p = Map<String, dynamic>.from(d['players'] as Map? ?? const {});
    final ids = p.keys.toList()..sort((a, b) => (p[a]['order'] as int).compareTo(p[b]['order'] as int));
    return [for (final u in ids) (u, p[u]['name'] as String? ?? "O'yinchi")];
  }

  void _call(String method, [Map<String, dynamic> extra = const {}]) =>
      _server.call(method, {'code': _code, ...extra}).catchError((_) => null);

  void _onRoom(Doc doc) {
    final d = doc.data();
    if (d == null) {
      setState(() => _error = 'Xona yopildi');
      return;
    }
    final state = d['state'] as String?;
    final round = d['round'] as int? ?? 1;

    if ((state == 'playing' || state == 'done') && _matchRound != round && d['first'] != null) {
      // Yangi raund boshlandi
      _matchRound = round;
      _moves.value = const [];
      _left.value = null;
      final startIn = ((d['startAt'] as int? ?? 0) - (d['serverNow'] as int? ?? 0)) / 1000;
      _match = OnlineMatch(
        code: _code,
        myUid: _uid,
        players: _players(d),
        first: d['first'] as String,
        seed: d['seed'] as int? ?? 0,
        countdown: startIn.clamp(0.0, 5.0),
        moves: _moves,
        left: _left,
        send: (m) => _call('play.move', {'m': m}),
        end: () => _call('play.end'),
        again: () => _call('play.again'),
      );
      HapticFeedback.mediumImpact();
    } else if (state == 'lobby') {
      _match = null;
      _matchRound = null;
    }

    if (_match != null) {
      final moves = (d['moves'] as List? ?? const []).cast<String>();
      if (!listEquals(moves, _moves.value)) _moves.value = List.unmodifiable(moves);
      final left = d['left'] as String?;
      if (left != null && left != _uid) _left.value = left;
    }
    setState(() => _room = d);
  }

  void _invite(String title) {
    final link = _server.roomInviteLink('$kPlayLinkPrefix$_code');
    final text = "$title o'ynaymizmi? ♟️ Havolani bosib kiring!";
    Telegram.openLink(
      'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(text)}',
    );
    Clipboard.setData(ClipboardData(text: link));
  }

  @override
  Widget build(BuildContext context) {
    final d = _room;
    final kind = d == null ? null : kOnlineGames[d['game']];
    final match = _match;
    if (match != null && kind != null) {
      return KeyedSubtree(key: ValueKey('round-$_matchRound'), child: kind.build(match));
    }
    return GameScaffold(
      title: kind == null ? 'Onlayn xona' : "${kind.title} — do'st bilan",
      palette: kind?.palette ?? GamePalette.home,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            )
          : d == null || kind == null
              ? const Center(child: CircularProgressIndicator())
              : _lobby(d, kind),
    );
  }

  Widget _lobby(Map<String, dynamic> d, OnlineGameKind kind) {
    final players = _players(d);
    final raw = Map<String, dynamic>.from(d['players'] as Map);
    final ready = raw[_uid]?['ready'] == true;
    final isHost = d['host'] == _uid;
    const colors = [Color(0xFF5CFF8A), Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF4FC3F7)];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlowText('Kutish xonasi', size: 26, color: Colors.white),
        const SizedBox(height: 6),
        const Text(
          "Hamma «Tayyorman» ni bosgach, o'yin boshlanadi",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        for (var k = 0; k < kind.maxPlayers; k++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: k < players.length ? 0.1 : 0.04),
              border: Border.all(color: k < players.length ? colors[k].withValues(alpha: 0.7) : Colors.white12),
            ),
            child: Row(
              children: [
                Icon(k < players.length ? Icons.person_rounded : Icons.person_outline_rounded,
                    color: k < players.length ? colors[k] : Colors.white24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    k < players.length
                        ? '${players[k].$2}${players[k].$1 == _uid ? ' (siz)' : ''}'
                        : "Bo'sh joy",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: k < players.length ? Colors.white : Colors.white30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (k < players.length)
                  raw[players[k].$1]?['ready'] == true
                      ? const Text('✓ Tayyor', style: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.w800))
                      : const Text('kutilmoqda…', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        const SizedBox(height: 18),
        if (isHost) ...[
          GameButton(
            key: const ValueKey('invite'),
            label: "Do'stni taklif qilish",
            icon: Icons.person_add_alt_1_rounded,
            colors: const [Color(0xFF4FC3F7), Color(0xFF1565C0)],
            onPressed: players.length >= kind.maxPlayers ? null : () => _invite(kind.title),
          ),
          const SizedBox(height: 10),
        ],
        GameButton(
          key: const ValueKey('ready'),
          label: ready ? 'Tayyorman ✓ (bekor qilish)' : 'Tayyorman',
          icon: ready ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
          colors: ready
              ? const [Color(0xFF66BB6A), Color(0xFF2E7D32)]
              : const [Color(0xFFFFC233), Color(0xFFFF6A3D)],
          onPressed: () {
            HapticFeedback.selectionClick();
            _call('play.ready', {'ready': !ready});
          },
        ),
        if (players.length < 2)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text("Boshlash uchun kamida 2 kishi kerak",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ),
      ],
    );
  }
}
