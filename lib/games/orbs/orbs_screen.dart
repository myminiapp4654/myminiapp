import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import 'orbs_game.dart';

const kOrbColors = [
  Color(0xFFFF5C8A),
  Color(0xFF4DD0FF),
  Color(0xFFFFD54F),
  Color(0xFF69F0AE),
  Color(0xFFB388FF),
  Color(0xFFFF9E57),
];

Color orbColor(int c) => c < 0 ? Colors.white : kOrbColors[c % kOrbColors.length];

/// Chain Burst: bir bosishda zanjirli portlash.
class OrbsScreen extends StatefulWidget {
  const OrbsScreen({super.key});

  @override
  State<OrbsScreen> createState() => _OrbsScreenState();
}

class _OrbsScreenState extends State<OrbsScreen> with SingleTickerProviderStateMixin {
  static const _saveKey = 'chainburst_progress_v2';

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  OrbsGame? _game;
  OrbsResult _shown = OrbsResult.playing;
  int _seenCatches = 0;

  /// Daraja -> eng yaxshi yulduzlar.
  Map<int, int> _stars = {};

  int get _unlocked => min(OrbsGame.levelCount, _stars.isEmpty ? 1 : _stars.keys.reduce(max) + 1);

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
      await prefs.setString(_saveKey, jsonEncode(_stars.map((k, v) => MapEntry('$k', v))));
    } catch (_) {}
  }

  void _start(int level) => setState(() {
        _game = OrbsGame(level.clamp(1, OrbsGame.levelCount));
        _shown = OrbsResult.playing;
        _seenCatches = 0;
      });

  int _starsFor(OrbsGame g) {
    final i = g.info;
    if (g.caught >= i.total) return 3;
    if (g.caught >= i.target + (i.total - i.target) ~/ 2) return 2;
    return 1;
  }

  void _onFrame(Duration elapsed) {
    final g = _game;
    if (g == null) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    g.update(dt);

    if (g.catches.length > _seenCatches) {
      _seenCatches = g.catches.length;
      HapticFeedback.lightImpact();
    }
    final r = g.result;
    if (r != OrbsResult.playing && _shown == OrbsResult.playing) {
      _shown = r;
      if (r == OrbsResult.won) {
        final s = _starsFor(g);
        if (s > (_stars[g.level] ?? 0)) _stars[g.level] = s;
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
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (var l = 1; l <= OrbsGame.levelCount; l++)
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
                            ? const LinearGradient(colors: [Color(0xFFB388FF), Color(0xFF5E35B1)])
                            : null,
                        color: l <= _unlocked ? null : Colors.white10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (l <= _unlocked)
                            Text('$l',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))
                          else
                            const Icon(Icons.lock_rounded, color: Colors.white38, size: 18),
                          Text(
                            '${OrbsGame.levels[l - 1].target}/${OrbsGame.levels[l - 1].total}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                          Text('★' * (_stars[l] ?? 0),
                              style: const TextStyle(fontSize: 11, color: Color(0xFFFFD54F))),
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
          backgroundColor: Color(0xFF07020F), body: Center(child: CircularProgressIndicator()));
    }
    final info = g.info;
    final progress = min(1.0, g.caught / info.target);
    final reached = g.caught >= info.target;

    return GameScaffold(
      title: 'Chain Burst: ${g.level}-daraja',
      palette: GamePalette.chain,
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
                  tint: const Color(0xFFB388FF),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${info.total} tadan ${info.target} tasini ushlang',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  Container(height: 10, color: Colors.white12),
                                  AnimatedFractionallySizedBox(
                                    duration: const Duration(milliseconds: 200),
                                    widthFactor: progress,
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: reached
                                              ? const [Color(0xFFFFE082), Color(0xFFFFB300)]
                                              : const [Color(0xFFB388FF), Color(0xFFFF5C8A)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Ochko: ${g.score}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: reached
                              ? const Color(0xFFFFB300).withValues(alpha: 0.25)
                              : Colors.black26,
                          border: Border.all(
                              color: reached ? const Color(0xFFFFD54F) : Colors.white24),
                        ),
                        child: Text('${g.caught} / ${info.target}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
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
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                      child: CustomPaint(painter: _ArenaPainter(g))),
                                  if (!g.tapped)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 24,
                                      child: IgnorePointer(
                                        child: Center(
                                          child: _Pulse(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Bir marta bosing — zanjirni boshlang!',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
    final last = g.level >= OrbsGame.levelCount;
    final stars = won ? _starsFor(g) : 0;
    return WinOverlay(
      key: ValueKey('res-${g.level}-$won'),
      title: won ? (last ? 'Hammasidan o\'tdingiz!' : 'Bajarildi!') : "Yana urinib ko'ring",
      subtitle: '${g.caught} ta ushlandi (kerak: ${g.info.target})  •  ${g.score} ochko'
          '${g.maxGeneration > 1 ? '\nEng uzun zanjir: ${g.maxGeneration}' : ''}',
      confetti: won,
      color: won ? const Color(0xFFFFD54F) : const Color(0xFFFF8A80),
      actions: [
        if (won)
          Text('★' * stars + '☆' * (3 - stars),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 38, color: Color(0xFFFFD54F), shadows: [
                Shadow(color: Color(0xFFFFB300), blurRadius: 14),
              ])),
        if (won && !last)
          GameButton(
            label: 'Keyingi daraja',
            icon: Icons.arrow_forward_rounded,
            colors: const [Color(0xFFB388FF), Color(0xFF5E35B1)],
            onPressed: () => _start(g.level + 1),
          ),
        GameButton(
          label: 'Qaytadan',
          icon: Icons.replay_rounded,
          outlined: won,
          colors: const [Color(0xFFB388FF), Color(0xFF5E35B1)],
          onPressed: () => _start(g.level),
        ),
      ],
    );
  }
}

/// Sekin "nafas oladigan" ko'rsatma.
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
        child: widget.child,
      );
}

class _ArenaPainter extends CustomPainter {
  final OrbsGame game;
  _ArenaPainter(this.game);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / OrbsGame.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1C0F33), Color(0xFF07020F)],
        ).createShader(Offset.zero & size),
    );

    // Portlash halqalari
    for (final b in game.blasts) {
      final r = OrbsGame.blastRadius * b.scale * s;
      if (r <= 0.5) continue;
      final c = Offset(b.x * s, b.y * s);
      final col = orbColor(b.color);
      final fade = b.age > Blast.grow + Blast.hold ? b.scale : 1.0;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            col.withValues(alpha: 0.55 * fade),
            col.withValues(alpha: 0.3 * fade),
            col.withValues(alpha: 0.05),
          ], stops: const [0, 0.7, 1])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = col.withValues(alpha: 0.8 * fade),
      );
    }

    // Suzib yurgan sharlar
    final r = OrbsGame.orbRadius * s;
    for (final o in game.orbs) {
      if (!o.alive) continue;
      final c = Offset(o.x * s, o.y * s);
      final col = orbColor(o.color);
      canvas.drawCircle(
        c,
        r * 2.4,
        Paint()
          ..shader = RadialGradient(colors: [col.withValues(alpha: 0.35), col.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r * 2.4)),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: [Colors.white, col, Color.lerp(col, Colors.black, 0.35)!],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // "+200" yozuvlari (har ushlangan shar ustida, ~0.9 s)
    final now = game.time;
    final recent = game.catches.length > 40
        ? game.catches.sublist(game.catches.length - 40)
        : game.catches;
    for (final c in recent) {
      final age = now - c.time;
      if (age > 0.9) continue;
      final t = age / 0.9;
      final tp = TextPainter(
        text: TextSpan(
          text: '+${c.points}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 1 - t),
            fontSize: 12 + min(c.generation, 6) * 1.5,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.x * s - tp.width / 2, c.y * s - 18 - 26 * t));
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaPainter old) => true;
}
