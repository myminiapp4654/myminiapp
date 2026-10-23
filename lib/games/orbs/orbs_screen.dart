import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telegram/telegram.dart';
import 'orbs_game.dart';

const kOrbColors = [
  Color(0xFFFF5252),
  Color(0xFF40C4FF),
  Color(0xFFFFD740),
  Color(0xFF69F0AE),
  Color(0xFFB388FF),
];
const kOrbColorNames = ['qizil', "ko'k", 'sariq', 'yashil', 'binafsha'];

Color orbColor(int c) => c == OrbsGame.bomb ? const Color(0xFF263238) : kOrbColors[c];

class OrbsScreen extends StatefulWidget {
  const OrbsScreen({super.key});

  @override
  State<OrbsScreen> createState() => _OrbsScreenState();
}

class _OrbsScreenState extends State<OrbsScreen>
    with SingleTickerProviderStateMixin {
  static const _saveKey = 'orbs_progress_v1';

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  OrbsGame? _game;

  /// Daraja -> eng yaxshi yulduzlar.
  Map<int, int> _stars = {};
  OrbsResult _shown = OrbsResult.playing;
  int _lastBursts = 0;

  int get _unlocked => _stars.isEmpty ? 1 : _stars.keys.reduce(max) + 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _stars = m.map((k, v) => MapEntry(int.parse(k), v as int));
      }
    } catch (_) {}
    if (mounted) _start(_unlocked);
  }

  Future<void> _saveStars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _saveKey, jsonEncode(_stars.map((k, v) => MapEntry('$k', v))));
    } catch (_) {}
  }

  void _start(int level) => setState(() {
        _game = OrbsGame(level);
        _shown = OrbsResult.playing;
        _lastBursts = 0;
      });

  void _onFrame(Duration elapsed) {
    final g = _game;
    if (g == null) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    g.update(dt);

    // Yangi portlashlar — titrash
    final popped = g.orbs.length - g.aliveCount;
    if (popped > _lastBursts) {
      HapticFeedback.lightImpact();
      _lastBursts = popped;
    }

    final r = g.result;
    if (r != OrbsResult.playing && _shown == OrbsResult.playing && g.settled) {
      _shown = r;
      if (r == OrbsResult.won) {
        final best = _stars[g.level] ?? 0;
        if (g.stars > best) _stars[g.level] = g.stars;
        _saveStars();
      }
    }
    setState(() {});
  }

  void _tapAt(Offset local, Size size) {
    final g = _game!;
    final scale = size.width / OrbsGame.width;
    if (g.tap(local.dx / scale, local.dy / scale)) {
      Telegram.haptic();
      HapticFeedback.mediumImpact();
    }
  }

  void _openLevels() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => GridView.count(
        crossAxisCount: 5,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var l = 1; l <= max(_unlocked, 10); l++)
            OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: l <= _unlocked
                  ? () {
                      Navigator.pop(ctx);
                      _start(l);
                    }
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$l'),
                  Text('★' * (_stars[l] ?? 0),
                      style: const TextStyle(fontSize: 10, color: Colors.amber)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final text = Theme.of(context).textTheme;
    if (g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final goalText = g.goal.color == null
        ? 'Sharlarni portlating'
        : '${kOrbColorNames[g.goal.color!][0].toUpperCase()}'
            "${kOrbColorNames[g.goal.color!].substring(1)} sharlarni yo'q qiling";

    return Scaffold(
      appBar: AppBar(
        title: Text('Chain Burst: ${g.level}-daraja'),
        actions: [
          IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Darajalar',
              onPressed: _openLevels),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Qaytadan',
              onPressed: () => _start(g.level)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  if (g.goal.color != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                          radius: 8, backgroundColor: orbColor(g.goal.color!)),
                    ),
                  Expanded(child: Text(goalText, style: text.titleSmall)),
                  Text('${min(g.progress, g.goal.target)}/${g.goal.target}',
                      style: text.titleMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(
                  value: min(1.0, g.progress / g.goal.target)),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Yurishlar: ${g.moves}', style: text.titleMedium),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: AspectRatio(
                    aspectRatio: OrbsGame.width / OrbsGame.height,
                    child: LayoutBuilder(builder: (context, box) {
                      final size = Size(box.maxWidth, box.maxHeight);
                      return GestureDetector(
                        key: const ValueKey('arena'),
                        onTapDown: (d) => _tapAt(d.localPosition, size),
                        child: Stack(
                          children: [
                            CustomPaint(size: size, painter: _ArenaPainter(g)),
                            if (_shown != OrbsResult.playing)
                              Positioned.fill(child: _buildResult(g)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(OrbsGame g) {
    final won = _shown == OrbsResult.won;
    final text = Theme.of(context).textTheme;
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(won ? 'Bajarildi!' : 'Yurishlar tugadi', style: text.headlineSmall),
          if (won)
            Text('★' * g.stars + '☆' * (3 - g.stars),
                style: const TextStyle(fontSize: 36, color: Colors.amber)),
          const SizedBox(height: 16),
          if (won)
            FilledButton(
              onPressed: () => _start(g.level + 1),
              child: const Text('Keyingi daraja'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _start(g.level),
            child: const Text('Qaytadan'),
          ),
        ],
      ),
    );
  }
}

class _ArenaPainter extends CustomPainter {
  final OrbsGame game;
  _ArenaPainter(this.game);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / OrbsGame.width;
    final r = OrbsGame.radius * s;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFF1A1D24),
    );

    // Portlash halqalari
    for (final b in game.bursts) {
      final t = (b.age / 0.45).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(b.x * s, b.y * s),
        r * (1 + t * (b.color == OrbsGame.bomb ? 4 : 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - t)
          ..color = (b.color == OrbsGame.bomb ? Colors.orange : orbColor(b.color))
              .withValues(alpha: 1 - t),
      );
    }

    final goal = game.goal.color;
    for (final o in game.orbs) {
      if (!o.alive) continue;
      final c = Offset(o.x * s, o.y * s);
      final base = orbColor(o.color);
      canvas.drawCircle(
        c,
        r * 0.96,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [Color.lerp(base, Colors.white, 0.45)!, base],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      if (o.isBomb) {
        // Bomba: ichida to'q sariq "pilik"
        canvas.drawCircle(c, r * 0.28, Paint()..color = Colors.orangeAccent);
      } else if (goal != null && o.color == goal) {
        canvas.drawCircle(
          c,
          r * 0.96,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white70,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}
