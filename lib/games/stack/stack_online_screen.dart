import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../net/server_client.dart';
import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import 'stack_race_screen.dart';

/// Taklif havolasidagi belgi: `stack_<KOD>`.
const kStackLinkPrefix = 'stack_';

/// Onlayn Stack: xona (kutish) → hamma "Tayyorman" → 3 soniya → musobaqa.
///
/// Xonani faqat admin ochadi ([create]), do'stlar taklif havolasi bilan kiradi.
class StackOnlineScreen extends StatefulWidget {
  final String code;
  const StackOnlineScreen({super.key, required this.code});

  /// Admin: yangi xona ochib, ekranga o'tadi.
  static Future<void> create(BuildContext context) async {
    try {
      final r = await ServerClient.instance.call<Map>('stack.create');
      final code = r?['code'] as String?;
      if (code == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StackOnlineScreen(code: code)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  State<StackOnlineScreen> createState() => _StackOnlineScreenState();
}

class _StackOnlineScreenState extends State<StackOnlineScreen> {
  final _server = ServerClient.instance;
  StreamSubscription<Doc>? _sub;
  Map<String, dynamic>? _room;
  String? _error;

  /// Joriy musobaqa (o'yin boshlanganda yaratiladi).
  List<StackLane>? _lanes;
  double _countdown = 3;
  int _raceId = 0;

  String get _uid => _server.myUid;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      await _server.call('stack.join', {'code': widget.code});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      return;
    }
    _sub = _server.watch('stack/${widget.code}').listen(_onRoom);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _server.call('stack.leave', {'code': widget.code}).catchError((_) => null);
    super.dispose();
  }

  Map<String, dynamic> _players(Map<String, dynamic> d) =>
      Map<String, dynamic>.from(d['players'] as Map? ?? const {});

  void _onRoom(Doc doc) {
    final d = doc.data();
    if (d == null) {
      setState(() => _error = 'Xona yopildi');
      return;
    }
    final state = d['state'];
    final players = _players(d);

    if (state == 'playing' && _lanes == null) {
      // Musobaqa boshlandi: men birinchi, qolganlar kirgan tartibida
      final others = players.keys.where((u) => u != _uid).toList()
        ..sort((a, b) => (players[a]['order'] as int).compareTo(players[b]['order'] as int));
      final startIn = ((d['startAt'] as int) - (d['serverNow'] as int)) / 1000;
      _countdown = startIn.clamp(0.5, 5.0);
      _lanes = [
        StackLane(players[_uid]?['name'] as String? ?? 'Siz', isMe: true, id: _uid),
        for (final u in others) StackLane(players[u]['name'] as String, id: u),
      ];
      _raceId++;
      HapticFeedback.mediumImpact();
    } else if (state == 'lobby' && _lanes != null) {
      _lanes = null; // "yana o'ynash" — xonaga qaytdik
    }

    // Raqiblarning yangi yurishlari
    final lanes = _lanes;
    if (lanes != null) {
      for (final l in lanes) {
        if (l.isMe) continue;
        final p = players[l.id];
        if (p == null) {
          l.gone = true;
          continue;
        }
        final moves = (p['moves'] as List).cast<num>();
        for (var k = l.received; k < moves.length; k++) {
          l.pendingMoves.add(moves[k].toDouble());
        }
        l.received = moves.length;
      }
    }
    setState(() => _room = d);
  }

  void _invite() {
    final link = _server.roomInviteLink('$kStackLinkPrefix${widget.code}');
    final text = "Stack'da bellashamizmi? 🏗️ Kim baland minora quradi!";
    Telegram.openLink(
      'https://t.me/share/url?url=${Uri.encodeComponent(link)}&text=${Uri.encodeComponent(text)}',
    );
    Clipboard.setData(ClipboardData(text: link));
  }

  @override
  Widget build(BuildContext context) {
    final lanes = _lanes;
    if (lanes != null) {
      return StackRaceScreen(
        key: ValueKey('race-$_raceId'),
        lanes: lanes,
        countdown: _countdown,
        title: "Stack — do'stlar bilan",
        onPlace: (offset) =>
            _server.call('stack.place', {'code': widget.code, 'offset': offset}).catchError((_) => null),
        onOver: () => _server.call('stack.over', {'code': widget.code}).catchError((_) => null),
        onAgain: () => _server.call('stack.again', {'code': widget.code}).catchError((_) => null),
      );
    }
    return GameScaffold(
      title: "Stack — do'stlar bilan",
      palette: GamePalette.stack,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            )
          : _room == null
              ? const Center(child: CircularProgressIndicator())
              : _lobby(_room!),
    );
  }

  Widget _lobby(Map<String, dynamic> d) {
    final players = _players(d);
    final order = players.keys.toList()
      ..sort((a, b) => (players[a]['order'] as int).compareTo(players[b]['order'] as int));
    final me = players[_uid] as Map?;
    final ready = me?['ready'] == true;
    final isHost = d['host'] == _uid;
    final waiting = d['state'] != 'lobby'; // boshqalar hali o'ynayapti

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GlowText('Kutish xonasi', size: 26, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          waiting
              ? "Oldingi o'yin hali tugamadi…"
              : "Hamma «Tayyorman» ni bosgach, 3 soniyadan keyin boshlanadi",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        for (var k = 0; k < 4; k++) _slot(k < order.length ? players[order[k]] as Map : null, k, order),
        const SizedBox(height: 18),
        if (isHost) ...[
          GameButton(
            key: const ValueKey('invite'),
            label: "Do'stni taklif qilish",
            icon: Icons.person_add_alt_1_rounded,
            colors: const [Color(0xFF4FC3F7), Color(0xFF1565C0)],
            onPressed: order.length >= 4 ? null : _invite,
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
          onPressed: waiting
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  _server.call('stack.ready', {'code': widget.code, 'ready': !ready}).catchError((_) => null);
                },
        ),
        if (order.length < 2)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text("Boshlash uchun kamida 2 kishi kerak",
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          ),
      ],
    );
  }

  Widget _slot(Map? p, int k, List<String> order) {
    const colors = [Color(0xFF5CFF8A), Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF81C784)];
    final isMe = p != null && order[k] == _uid;
    final ready = p?['ready'] == true;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: p == null ? 0.04 : 0.1),
        border: Border.all(color: p == null ? Colors.white12 : colors[k].withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(p == null ? Icons.person_outline_rounded : Icons.person_rounded,
              color: p == null ? Colors.white24 : colors[k]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p == null ? "Bo'sh joy" : '${p['name']}${isMe ? ' (siz)' : ''}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p == null ? Colors.white30 : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (p != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: ready
                  ? const Row(
                      key: ValueKey('r'),
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF66BB6A)),
                        SizedBox(width: 4),
                        Text('Tayyor', style: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.w800)),
                      ],
                    )
                  : const Text('kutilmoqda…',
                      key: ValueKey('w'), style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
