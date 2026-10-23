import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telegram/telegram.dart';
import 'orbs_game.dart';
import '../../ui/kit.dart';

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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Darajalar',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var l = 1; l <= max(_unlocked, 10); l++)
                  GestureDetector(
                    onTap: l <= _unlocked
                        ? () {
                            Navigator.pop(ctx);
                            _start(l);
                          }
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: l <= _unlocked
                            ? const LinearGradient(
                                colors: [Color(0xFF00C9A7), Color(0xFF00695C)])
                            : null,
                        color: l <= _unlocked ? null : Colors.white10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (l <= _unlocked)
                            Text('$l',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18))
                          else
                            const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
                          Text('★' * (_stars[l] ?? 0),
                              style: const TextStyle(fontSize: 10, color: Color(0xFFFFD54F))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF050D18),
          body: Center(child: CircularProgressIndicator()));
    }

    final goalText = g.goal.color == null
        ? 'Sharlarni portlating'
        : '${kOrbColorNames[g.goal.color!][0].toUpperCase()}'
            "${kOrbColorNames[g.goal.color!].substring(1)} sharlarni yo'q qiling";
    final progress = min(1.0, g.progress / g.goal.target);

    return GameScaffold(
      title: 'Chain Burst: ${g.level}-daraja',
      palette: GamePalette.orbs,
      actions: [
        IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Darajalar',
            onPressed: _openLevels),
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Qaytadan',
            onPressed: () => _start(g.level)),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Glass(
                  tint: const Color(0xFF7CF5C4),
                  child: Row(
                    children: [
                      // Vazifa rangi
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: g.goal.color == null
                              ? const SweepGradient(colors: kOrbColors)
                              : RadialGradient(
                                  center: const Alignment(-0.3, -0.3),
                                  colors: [
                                    Colors.white,
                                    orbColor(g.goal.color!),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goalText,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  Container(height: 10, color: Colors.white12),
                                  AnimatedFractionallySizedBox(
                                    duration: const Duration(milliseconds: 300),
                                    widthFactor: progress,
                                    child: Container(
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [Color(0xFF7CF5C4), Color(0xFF00C9A7)]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${min(g.progress, g.goal.target)}/${g.goal.target}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Qolgan yurishlar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black26,
                          border: Border.all(
                            color: g.moves <= 1 ? const Color(0xFFFF5252) : const Color(0xFF7CF5C4),
                            width: 2.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${g.moves}',
                                key: const ValueKey('moves'),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                            const Text('yurish',
                                style: TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF7CF5C4).withValues(alpha: 0.35)),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CustomPaint(size: size, painter: _ArenaPainter(g)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_shown != OrbsResult.playing) Positioned.fill(child: _buildResult(g)),
        ],
      ),
    );
  }

  Widget _buildResult(OrbsGame g) {
    final won = _shown == OrbsResult.won;
    return WinOverlay(
      key: ValueKey('res-${g.level}-$won'),
      title: won ? 'Bajarildi!' : 'Yurishlar tugadi',
      subtitle: won
          ? '${'★' * g.stars}${'☆' * (3 - g.stars)}'
          : 'Vazifa: ${g.progress}/${g.goal.target}',
      confetti: won,
      color: won ? const Color(0xFF7CF5C4) : const Color(0xFFFF8A80),
      actions: [
        if (won)
          GameButton(
            label: 'Keyingi daraja',
            icon: Icons.arrow_forward_rounded,
            colors: const [Color(0xFF7CF5C4), Color(0xFF00897B)],
            onPressed: () => _start(g.level + 1),
          ),
        GameButton(
          label: 'Qaytadan',
          icon: Icons.replay_rounded,
          outlined: won,
          colors: const [Color(0xFF7CF5C4), Color(0xFF00897B)],
          onPressed: () => _start(g.level),
        ),
      ],
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

    // Fon: qorong'i shisha, mayda nuqtalar
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E2236), Color(0xFF07121F)],
        ).createShader(Offset.zero & size),
    );
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var y = s / 2; y < size.height; y += s) {
      for (var x = s / 2; x < size.width; x += s) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }

    // Portlash halqalari va uchqunlar
    for (final b in game.bursts) {
      final t = (b.age / 0.45).clamp(0.0, 1.0);
      final c = Offset(b.x * s, b.y * s);
      final bomb = b.color == OrbsGame.bomb;
      final col = bomb ? const Color(0xFFFF9100) : orbColor(b.color);
      canvas.drawCircle(
        c,
        r * (1 + t * (bomb ? 4 : 1.8)),
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.6 * (1 - t)),
            col.withValues(alpha: 0.45 * (1 - t)),
            col.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r * (1 + t * (bomb ? 4 : 1.8)))),
      );
      for (var k = 0; k < 6; k++) {
        final a = k * pi / 3 + b.x;
        final p = c + Offset(cos(a), sin(a)) * r * (0.5 + t * (bomb ? 3.5 : 1.8));
        canvas.drawCircle(p, r * 0.18 * (1 - t), Paint()..color = col.withValues(alpha: 1 - t));
      }
    }

    final goal = game.goal.color;
    for (final o in game.orbs) {
      if (!o.alive) continue;
      final c = Offset(o.x * s, o.y * s);
      if (o.isBomb) {
        _bomb(canvas, c, r);
        continue;
      }
      final base = orbColor(o.color);
      // Nur
      if (goal == o.color) {
        canvas.drawCircle(c, r * 1.25, Paint()
          ..shader = RadialGradient(colors: [base.withValues(alpha: 0.35), base.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r * 1.25)));
      }
      canvas.drawCircle(
        c,
        r * 0.95,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [
              Colors.white,
              Color.lerp(base, Colors.white, 0.35)!,
              base,
              Color.lerp(base, Colors.black, 0.5)!,
            ],
            stops: const [0, 0.15, 0.55, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  void _bomb(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 0.95,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFF8A939C), Color(0xFF2B3238), Color(0xFF0B0D10)],
          stops: [0, 0.4, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Pilik va uchqun
    final fuse = c + Offset(r * 0.45, -r * 0.75);
    canvas.drawLine(c + Offset(r * 0.2, -r * 0.6), fuse,
        Paint()
          ..color = const Color(0xFFBCAAA4)
          ..strokeWidth = r * 0.14
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(fuse, r * 0.3, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFF9100), Color(0x00FF9100)])
          .createShader(Rect.fromCircle(center: fuse, radius: r * 0.3)));
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}
