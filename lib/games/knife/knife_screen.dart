import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../net/server_client.dart';
import '../../ui/kit.dart';
import 'knife_game.dart';

const _bestKey = 'knife_best';

/// Pichoq otish: bosing — pichoq nishonga uchadi.
class KnifeScreen extends StatefulWidget {
  final int? seed;
  const KnifeScreen({super.key, this.seed});

  @override
  State<KnifeScreen> createState() => _KnifeScreenState();
}

class _Entry {
  final String uid, name;
  final int score;
  const _Entry(this.uid, this.name, this.score);
}

class _KnifeScreenState extends State<KnifeScreen> with SingleTickerProviderStateMixin {
  late KnifeGame _game = KnifeGame(seed: widget.seed);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  int _best = 0;
  bool _newRecord = false;
  double? _overAt;
  int _seenEvents = 0;

  StreamSubscription<Doc>? _scoresSub;
  List<_Entry> _top = const [];
  bool get _online => ServerClient.instance.state.value == ConnState.online;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _loadBest();
    if (_online) {
      _scoresSub = ServerClient.instance.watch('scores/knife').listen((doc) {
        final list = (doc.data()?['top'] as List?) ?? const [];
        setState(() {
          _top = [
            for (final e in list)
              _Entry(e['uid'] as String? ?? '', e['name'] as String? ?? '?', e['score'] as int? ?? 0),
          ];
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scoresSub?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b = prefs.getInt(_bestKey) ?? 0;
      if (!mounted) return;
      setState(() => _best = b);
      if (b > 0) _submit(b);
    } catch (_) {}
  }

  void _submit(int score) {
    if (!_online) return;
    ServerClient.instance.call('score.submit', {'game': 'knife', 'score': score}).catchError((_) => null);
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _game.update(dt);
    // Yangi voqealar uchun tebranish
    final events = _game.events;
    for (var k = _seenEvents.clamp(0, events.length); k < events.length; k++) {
      switch (events[k].type) {
        case KnifeEventType.hit:
          HapticFeedback.selectionClick();
        case KnifeEventType.apple:
          HapticFeedback.mediumImpact();
        case KnifeEventType.cleared:
          HapticFeedback.heavyImpact();
        case KnifeEventType.fail:
          HapticFeedback.heavyImpact();
          _gameOver();
      }
    }
    _seenEvents = events.length;
    setState(() {});
  }

  void _gameOver() {
    _overAt = _game.time;
    final s = _game.score;
    _newRecord = s > _best;
    if (_newRecord) {
      _best = s;
      SharedPreferences.getInstance().then((p) => p.setInt(_bestKey, s)).catchError((_) => false);
    }
    _submit(s);
  }

  void _tap() {
    if (_game.throwKnife()) HapticFeedback.lightImpact();
  }

  void _again() => setState(() {
        _game = KnifeGame();
        _overAt = null;
        _newRecord = false;
        _seenEvents = 0;
      });

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return GameScaffold(
      title: 'Pichoq otish',
      palette: GamePalette.knife,
      body: GestureDetector(
        key: const ValueKey('knife'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ScenePainter(g)),
            ),
            // Hisob va bosqich
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text('${g.score}',
                        key: const ValueKey('knife-score'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                        )),
                    _stageDots(g),
                    const SizedBox(height: 4),
                    Text(
                      g.isBoss ? '⚔️ BOSS — ${g.stage}-bosqich' : '${g.stage}-bosqich',
                      style: TextStyle(
                        color: g.isBoss ? const Color(0xFFFF6E6E) : Colors.white70,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Olmalar
            Positioned(
              top: 12,
              right: 14,
              child: IgnorePointer(
                child: Row(
                  children: [
                    const Text('🍎', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text('${g.applesHit}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
            ),
            if (_overAt != null && g.time - _overAt! > 0.9) Positioned.fill(child: _overPanel()),
          ],
        ),
      ),
    );
  }

  /// Bosqich nuqtalari: 5 tadan, beshinchisi — boss.
  Widget _stageDots(KnifeGame g) {
    final first = (g.stage - 1) ~/ 5 * 5 + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var s = first; s < first + 5; s++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: s % 5 == 0 ? 16 : 10,
            height: s % 5 == 0 ? 16 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s < g.stage
                  ? const Color(0xFFFFC233)
                  : s == g.stage
                      ? Colors.white
                      : Colors.white24,
              border: s % 5 == 0 ? Border.all(color: const Color(0xFFFF6E6E), width: 2) : null,
            ),
          ),
      ],
    );
  }

  Widget _overPanel() {
    final myUid = ServerClient.instance.myUid;
    final top = _top.take(10).toList();
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Glass(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_game.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
              Text('${_game.stage}-bosqich  •  🍎 ${_game.applesHit}',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (_newRecord)
                const GlowText('🎉 Yangi rekord!', size: 22, color: Color(0xFFFFD54F))
              else
                Text('Rekordingiz: $_best', style: const TextStyle(color: Colors.white70)),
              if (top.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('🏆 Rekordlar jadvali',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                for (var k = 0; k < top.length; k++)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: top[k].uid == myUid ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(['🥇', '🥈', '🥉'].elementAtOrNull(k) ?? '${k + 1}.',
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        Expanded(
                          child: Text(top[k].name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        Text('${top[k].score}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              GameButton(
                key: const ValueKey('knife-again'),
                label: "Yana o'ynash",
                icon: Icons.replay_rounded,
                colors: const [Color(0xFFFFC233), Color(0xFFFF6A3D)],
                onPressed: _again,
              ),
              const SizedBox(height: 10),
              GameButton(
                label: 'Bosh menyu',
                outlined: true,
                colors: const [Colors.white70, Colors.white70],
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Butun sahna: nishon, pichoqlar, olmalar, effektlar.
class _ScenePainter extends CustomPainter {
  final KnifeGame g;
  _ScenePainter(this.g);

  @override
  void paint(Canvas canvas, Size size) {
    final r = min(size.width, size.height) * 0.22;
    final center = Offset(size.width / 2, size.height * 0.4);
    final knifeLen = r * 1.05;
    final bottomY = size.height * 0.86;

    // Nishon silkinishi (oxirgi sanchilishdan)
    var shake = Offset.zero;
    for (final e in g.events) {
      final age = g.time - e.at;
      if (e.type == KnifeEventType.hit && age < 0.12) shake = Offset(0, -6 * (1 - age / 0.12));
      if (e.type == KnifeEventType.fail && age < 0.4) {
        shake = Offset(sin(age * 80) * 8 * (1 - age / 0.4), 0);
      }
    }
    final c = center + shake;

    final cleared = g.clearedAt;
    if (cleared != null) {
      _shatter(canvas, c, r, knifeLen, g.time - cleared);
    } else {
      // Sanchilgan pichoqlar — nishon ostida (sopi tashqarida)
      for (final k in g.knives) {
        final a = k.angle + g.angle;
        final dir = Offset(cos(a), sin(a));
        drawKnife(canvas, c + dir * r * 0.72, dir, knifeLen);
      }
      _log(canvas, c, r);
      // Olmalar
      for (final a0 in g.apples) {
        final a = a0 + g.angle;
        _apple(canvas, c + Offset(cos(a), sin(a)) * (r + r * 0.17), r * 0.17, 1);
      }
    }

    // Effektlar: qirindilar, bo'lingan olma, qaytib tushgan pichoq
    for (final e in g.events) {
      final age = g.time - e.at;
      final hit = c + Offset(0, r);
      switch (e.type) {
        case KnifeEventType.hit:
          if (age < 0.45) _chips(canvas, hit, age, r);
        case KnifeEventType.apple:
          if (age < 0.9) _appleSplit(canvas, c + Offset(cos(e.angle + g.angle), sin(e.angle + g.angle)) * (r * 1.17), r * 0.17, age);
        case KnifeEventType.fail:
          final t = age.clamp(0.0, 1.2);
          final p = Offset(c.dx + 40 * t, c.dy + r + 20 + 420 * t * t);
          final rot = pi / 2 + t * 9;
          drawKnife(canvas, p, Offset(cos(rot), sin(rot)), knifeLen);
        case KnifeEventType.cleared:
          break;
      }
    }

    // Uchayotgan yoki tayyor pichoq
    if (!g.over && cleared == null) {
      final f = g.flyingSince;
      if (f != null) {
        final t = ((g.time - f) / KnifeGame.flight).clamp(0.0, 1.0);
        final tipY = bottomY - knifeLen - (bottomY - knifeLen - (c.dy + r * 0.72)) * t;
        drawKnife(canvas, Offset(c.dx, tipY), const Offset(0, 1), knifeLen);
      } else if (g.left > 0) {
        drawKnife(canvas, Offset(size.width / 2, bottomY - knifeLen), const Offset(0, 1), knifeLen);
      }
    }

    // Qolgan pichoqlar — chap pastda
    for (var k = 0; k < g.stageKnives; k++) {
      final used = k >= g.left;
      final y = size.height - 24 - k * 22.0;
      final p = Paint()
        ..color = used ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(18, y), Offset(40, y - 10), p);
    }
  }

  /// Nishon: oddiy bosqichda yog'och, bossda — tarvuz, pishloq yoki shina.
  void _log(Canvas canvas, Offset c, double r) {
    final boss = g.isBoss ? (g.stage ~/ 5 - 1) % 3 : -1;
    canvas.drawCircle(c + const Offset(0, 8), r * 1.02, Paint()..color = Colors.black38..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(g.angle);
    switch (boss) {
      case 0: // tarvuz
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF2E7D32));
        canvas.drawCircle(Offset.zero, r * 0.9, Paint()..color = const Color(0xFFC8E6C9));
        canvas.drawCircle(Offset.zero, r * 0.84, Paint()..color = const Color(0xFFE53935));
        final seed = Paint()..color = const Color(0xFF1B1B1B);
        for (var k = 0; k < 12; k++) {
          final a = k * pi / 6;
          canvas.save();
          canvas.rotate(a);
          canvas.drawOval(Rect.fromCenter(center: Offset(r * (0.45 + 0.2 * (k % 2)), 0), width: r * 0.09, height: r * 0.05), seed);
          canvas.restore();
        }
      case 1: // pishloq
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFFFFC107));
        canvas.drawCircle(Offset.zero, r * 0.93, Paint()..color = const Color(0xFFFFD54F));
        final hole = Paint()..color = const Color(0xFFE0A800);
        for (final (x, y, s) in const [(0.3, 0.2, 0.16), (-0.4, 0.1, 0.12), (0.0, -0.45, 0.14), (-0.2, 0.5, 0.1), (0.55, -0.3, 0.09)]) {
          canvas.drawCircle(Offset(x * r, y * r), s * r, hole);
        }
      case 2: // shina
        canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF212121));
        final tread = Paint()
          ..color = const Color(0xFF424242)
          ..strokeWidth = r * 0.05;
        for (var k = 0; k < 24; k++) {
          final a = k * pi / 12;
          canvas.drawLine(Offset(cos(a), sin(a)) * r * 0.82, Offset(cos(a), sin(a)) * r * 0.98, tread);
        }
        canvas.drawCircle(Offset.zero, r * 0.5, Paint()..color = const Color(0xFF9E9E9E));
        canvas.drawCircle(Offset.zero, r * 0.18, Paint()..color = const Color(0xFF616161));
      default: // yog'och
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = const RadialGradient(colors: [Color(0xFFE0B07A), Color(0xFFB5773F), Color(0xFF7A4A22)], stops: [0, 0.75, 1])
                .createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
        );
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFF8B5A2B).withValues(alpha: 0.5);
        for (var k = 1; k <= 5; k++) {
          canvas.drawCircle(Offset(r * 0.03 * k, 0), r * 0.15 * k, ring);
        }
        // Po'stloq
        canvas.drawCircle(
          Offset.zero,
          r * 0.97,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08
            ..color = const Color(0xFF5D3A1A),
        );
        canvas.drawLine(Offset.zero, Offset(r * 0.6, r * 0.2), ring);
    }
    canvas.restore();
  }

  /// Bosqich tugadi: nishon bo'laklarga bo'linib uchadi, pichoqlar tushadi.
  void _shatter(Canvas canvas, Offset c, double r, double knifeLen, double t) {
    final fade = (1 - t / 1.1).clamp(0.0, 1.0);
    for (var k = 0; k < 6; k++) {
      final a = k * pi / 3 + g.angle;
      final dir = Offset(cos(a + pi / 6), sin(a + pi / 6));
      final p = c + dir * (t * 260) + Offset(0, 300 * t * t);
      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..arcTo(Rect.fromCircle(center: p, radius: r), a, pi / 3, false)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFFB5773F).withValues(alpha: fade));
    }
    for (final k in g.knives) {
      final a = k.angle + g.angle;
      final dir = Offset(cos(a), sin(a));
      final p = c + dir * (r * 0.72 + t * 200) + Offset(0, 500 * t * t);
      final rot = a + t * 6;
      drawKnife(canvas, p, Offset(cos(rot), sin(rot)), knifeLen);
    }
  }

  void _chips(Canvas canvas, Offset p, double age, double r) {
    final q = age / 0.45;
    final paint = Paint()..color = const Color(0xFFE0B07A).withValues(alpha: 1 - q);
    for (var k = 0; k < 7; k++) {
      final a = pi / 2 + (k - 3) * 0.35;
      final d = Offset(cos(a), sin(a)) * (r * 0.5 * q);
      canvas.drawCircle(p + d + Offset(0, 60 * q * q), 3.5 * (1 - q) + 1, paint);
    }
  }

  void _apple(Canvas canvas, Offset p, double s, double alpha) {
    canvas.drawCircle(p, s, Paint()..color = const Color(0xFFE53935).withValues(alpha: alpha));
    canvas.drawCircle(p - Offset(s * 0.35, s * 0.35), s * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha));
    canvas.drawLine(p - Offset(0, s), p - Offset(-s * 0.2, s * 1.4),
        Paint()
          ..color = const Color(0xFF5D4037).withValues(alpha: alpha)
          ..strokeWidth = 2);
    canvas.drawOval(Rect.fromCenter(center: p - Offset(-s * 0.45, s * 1.15), width: s * 0.6, height: s * 0.3),
        Paint()..color = const Color(0xFF43A047).withValues(alpha: alpha));
  }

  void _appleSplit(Canvas canvas, Offset p, double s, double age) {
    final q = age / 0.9;
    final alpha = (1 - q).clamp(0.0, 1.0);
    for (final side in const [-1.0, 1.0]) {
      final c = p + Offset(side * 50 * q, 120 * q * q);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(side * q * 3);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: s), side > 0 ? -pi / 2 : pi / 2, pi, true,
          Paint()..color = const Color(0xFFE53935).withValues(alpha: alpha));
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: s * 0.8), side > 0 ? -pi / 2 : pi / 2, pi, true,
          Paint()..color = const Color(0xFFFFF3E0).withValues(alpha: alpha));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}

/// Pichoq: [tip] — tig' uchi, [dir] — uchdan sopga yo'nalish.
void drawKnife(Canvas canvas, Offset tip, Offset dir, double len) {
  final n = Offset(-dir.dy, dir.dx);
  final w = len * 0.11;
  final bladeEnd = tip + dir * len * 0.55;
  // Tig'
  final blade = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo((bladeEnd + n * w).dx, (bladeEnd + n * w).dy)
    ..lineTo((bladeEnd - n * w * 0.6).dx, (bladeEnd - n * w * 0.6).dy)
    ..close();
  canvas.drawPath(
    blade,
    Paint()
      ..shader = LinearGradient(colors: const [Color(0xFFF5F5F5), Color(0xFF9E9E9E)])
          .createShader(Rect.fromPoints(tip - n * w, bladeEnd + n * w)),
  );
  canvas.drawPath(blade, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.black26);
  // Dasta oldi (gard)
  final guard = Paint()
    ..color = const Color(0xFFFFC233)
    ..strokeWidth = w * 0.7
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(bladeEnd + n * w * 1.3, bladeEnd - n * w * 1.1, guard);
  // Sop
  final handleEnd = bladeEnd + dir * len * 0.45;
  canvas.drawLine(
    bladeEnd + dir * w * 0.5,
    handleEnd,
    Paint()
      ..color = const Color(0xFF6D3B1F)
      ..strokeWidth = w * 1.5
      ..strokeCap = StrokeCap.round,
  );
  final rivet = Paint()..color = const Color(0xFFFFE082);
  for (final f in const [0.35, 0.7]) {
    canvas.drawCircle(Offset.lerp(bladeEnd, handleEnd, f)!, w * 0.28, rivet);
  }
}
