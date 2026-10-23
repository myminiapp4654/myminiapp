import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../ui/kit.dart';
import 'snake_game.dart';

Color _c(int paletteIndex) => Color(Snake.palette[paletteIndex % Snake.palette.length]);

/// Neon Snake: barmoq bilan boshqariladigan ilon, kompyuter ilonlariga qarshi.
class SnakeScreen extends StatefulWidget {
  /// Kompyuter darajasi: 1 — oson, 2 — o'rta, 3 — qiyin
  final int level;

  /// Testlar uchun
  final int? seed;

  const SnakeScreen({super.key, this.level = 2, this.seed});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> with SingleTickerProviderStateMixin {
  late SnakeWorld _world = SnakeWorld(level: widget.level, seed: widget.seed);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// Joystik: barmoq tekkan joy va hozirgi joyi.
  Offset? _stickOrigin;
  Offset? _stickNow;
  bool _touched = false;

  /// Eng yaxshi natija shu sessiyada.
  int _best = 0;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    final wasAlive = _world.player.alive;
    _world.update(dt);
    final p = _world.player;
    if (p.alive && p.length > _lastLength && p.length % 10 == 0) HapticFeedback.selectionClick();
    _lastLength = p.length;
    if (wasAlive && !p.alive) {
      HapticFeedback.heavyImpact();
      _best = max(_best, p.length);
    }
    setState(() {});
  }

  void _restart() {
    setState(() {
      _world = SnakeWorld(level: widget.level, seed: widget.seed == null ? null : widget.seed! + 1);
      _stickOrigin = _stickNow = null;
    });
  }

  // ---------------------------------------------------------------- joystik

  void _down(Offset p) {
    _touched = true;
    setState(() {
      _stickOrigin = p;
      _stickNow = p;
    });
  }

  void _move(Offset p) {
    final o = _stickOrigin;
    if (o == null) return;
    var d = p - o;
    // Barmoq juda uzoqlashsa — joystik markazi ergashadi
    const maxR = 60.0;
    if (d.distance > maxR) {
      _stickOrigin = p - d / d.distance * maxR;
      d = p - _stickOrigin!;
    }
    if (d.distance > 6) _world.steer(atan2(d.dy, d.dx));
    setState(() => _stickNow = p);
  }

  void _up() => setState(() => _stickOrigin = _stickNow = null);

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final w = _world;
    final p = w.player;
    return GameScaffold(
      title: 'Neon Snake',
      palette: GamePalette.snake,
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              key: const ValueKey('arena'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _down(e.localPosition),
              onPointerMove: (e) => _move(e.localPosition),
              onPointerUp: (_) => _up(),
              onPointerCancel: (_) => _up(),
              child: ClipRect(
                child: CustomPaint(
                  painter: _WorldPainter(w, Theme.of(context).textTheme.bodyMedium!),
                  foregroundPainter: _StickPainter(_stickOrigin, _stickNow),
                ),
              ),
            ),
          ),
          // Uzunlik
          Positioned(
            left: 12,
            top: 8,
            child: IgnorePointer(
              child: Glass(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uzunlik: ${p.length}',
                        key: const ValueKey('length'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text("O'rin: ${p.alive ? w.playerRank : '—'} / ${w.leaderboard.length}",
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          // Reyting
          Positioned(right: 12, top: 8, child: IgnorePointer(child: _leaderboard())),
          // Kichik xarita
          Positioned(
            right: 12,
            bottom: 16,
            child: IgnorePointer(
              child: SizedBox(width: 86, height: 86, child: CustomPaint(painter: _MiniMapPainter(w))),
            ),
          ),
          if (!_touched)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: IgnorePointer(
                child: Center(
                  child: GlowText("Barmoqni suring — ilon o'sha tomonga yuradi",
                      size: 15, color: Color(0xFF00F5FF)),
                ),
              ),
            ),
          if (!p.alive && w.time - p.diedAt > 1.2)
            Positioned.fill(
              child: WinOverlay(
                title: "Ilon o'ldi",
                subtitle: 'Uzunlik: ${p.length}  •  rekord: $_best  •  yutilgan: ${p.kills}',
                confetti: false,
                color: const Color(0xFF00F5FF),
                actions: [
                  GameButton(
                    label: 'Qayta boshlash',
                    icon: Icons.replay_rounded,
                    colors: const [Color(0xFF00F5FF), Color(0xFFB967FF)],
                    onPressed: _restart,
                  ),
                  GameButton(
                    label: 'Bosh menyu',
                    outlined: true,
                    colors: const [Colors.white70, Colors.white70],
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaderboard() {
    final top = _world.leaderboard.take(5).toList();
    return Glass(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆 Reyting',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 4),
            for (var k = 0; k < top.length; k++)
              Row(
                children: [
                  Text('${k + 1}. ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Expanded(
                    child: Text(
                      top[k].name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _c(top[k].color),
                        fontSize: 11,
                        fontWeight: top[k].isPlayer ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Text('${top[k].length}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Dunyo: to'r, arena cheti, ozuqa, ilonlar, portlashlar. Kamera o'yinchi ortidan.
class _WorldPainter extends CustomPainter {
  final SnakeWorld w;

  /// Ismlar uchun ilova shrifti.
  final TextStyle text;
  _WorldPainter(this.w, this.text);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF05040B));
    final p = w.player;
    // Kattalashgan sari kamera uzoqlashadi
    final zoom = (size.shortestSide / 540) * (1.0 - min(0.3, (p.length - 14) * 0.0015));
    final cam = p.head;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-cam.dx, -cam.dy);

    final view = Rect.fromCenter(center: cam, width: size.width / zoom + 80, height: size.height / zoom + 80);
    _grid(canvas, view);
    _border(canvas);

    // Ozuqa
    final t = w.time;
    for (final f in w.food) {
      if (f.born > t || !view.contains(f.pos)) continue;
      final pulse = 0.8 + 0.2 * sin(t * 4 + f.pos.dx * 0.05);
      final r = (f.fromDeath ? 6.0 : 3.8) * pulse;
      final color = _c(f.color);
      canvas.drawCircle(f.pos, r * 2.4, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(f.pos, r, Paint()..color = color);
      canvas.drawCircle(f.pos, r * 0.4, Paint()..color = Colors.white.withValues(alpha: 0.8));
    }

    // Ilonlar (o'yinchi eng ustida)
    for (final s in w.snakes.reversed) {
      if (!s.alive) continue;
      if (!view.inflate(s.length * SnakeWorld.spacing).contains(s.head)) continue;
      _snake(canvas, s, view);
    }

    // Zanjirli portlashlar: boshdan dumga yuguradi
    for (final b in w.bursts) {
      final color = _c(b.color);
      for (var k = 0; k < b.points.length; k += 2) {
        final local = t - b.start - k * Burst.delay;
        if (local < 0 || local > Burst.ring) continue;
        final q = local / Burst.ring;
        final pt = b.points[k];
        if (!view.contains(pt)) continue;
        canvas.drawCircle(
          pt,
          6 + 26 * q,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - q)
            ..color = color.withValues(alpha: 1 - q),
        );
        canvas.drawCircle(pt, 10 * (1 - q), Paint()..color = Colors.white.withValues(alpha: (1 - q) * 0.9));
      }
    }
    canvas.restore();
  }

  void _grid(Canvas canvas, Rect view) {
    const step = 64.0;
    final paint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var x = (view.left / step).floor() * step; x < view.right; x += step) {
      canvas.drawLine(Offset(x, view.top), Offset(x, view.bottom), paint);
    }
    for (var y = (view.top / step).floor() * step; y < view.bottom; y += step) {
      canvas.drawLine(Offset(view.left, y), Offset(view.right, y), paint);
    }
  }

  void _border(Canvas canvas) {
    // Arena tashqarisi qorong'i, cheti qizil neon
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromCircle(center: Offset.zero, radius: SnakeWorld.radius * 2))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: SnakeWorld.radius));
    canvas.drawPath(outside, Paint()..color = const Color(0xFF1A0510));
    canvas.drawCircle(
      Offset.zero,
      SnakeWorld.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = const Color(0xFFFF2E5F).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      Offset.zero,
      SnakeWorld.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFF2E5F),
    );
  }

  void _snake(Canvas canvas, Snake s, Rect view) {
    final color = _c(s.color);
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final r = s.radius;

    // Neon nur
    final path = Path()..moveTo(s.segs.first.dx, s.segs.first.dy);
    for (final q in s.segs.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 2 + 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9),
    );

    // Bo'g'imlar: dumdan boshga, yo'l-yo'l
    for (var k = s.segs.length - 1; k >= 0; k--) {
      final q = s.segs[k];
      if (!view.contains(q)) continue;
      final rr = r * (k > s.segs.length - 6 ? 0.6 + 0.08 * (s.segs.length - k) : 1.0);
      canvas.drawCircle(q, rr, Paint()..color = (k ~/ 3).isEven ? color : dark);
      canvas.drawCircle(q - Offset(rr * 0.3, rr * 0.3), rr * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.25));
    }

    // Bosh va ko'zlar
    final h = s.head;
    canvas.drawCircle(h, r * 1.12, Paint()..color = color);
    final dir = Offset(cos(s.angle), sin(s.angle));
    final side = Offset(-dir.dy, dir.dx);
    for (final k in const [-1.0, 1.0]) {
      final e = h + dir * r * 0.35 + side * r * 0.5 * k;
      canvas.drawCircle(e, r * 0.38, Paint()..color = Colors.white);
      canvas.drawCircle(e + dir * r * 0.14, r * 0.2, Paint()..color = Colors.black);
    }

    // Kompyuter ismi
    if (!s.isPlayer) {
      final tp = TextPainter(
        text: TextSpan(
          text: s.name,
          style: text.copyWith(color: color.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, h + Offset(-tp.width / 2, -r - 20));
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) => true;
}

class _StickPainter extends CustomPainter {
  final Offset? origin;
  final Offset? now;
  _StickPainter(this.origin, this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final o = origin, n = now;
    if (o == null || n == null) return;
    canvas.drawCircle(
      o,
      60,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    canvas.drawCircle(o, 60, Paint()..color = Colors.white.withValues(alpha: 0.05));
    canvas.drawCircle(n, 24, Paint()..color = const Color(0xFF00F5FF).withValues(alpha: 0.35));
    canvas.drawCircle(
      n,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00F5FF).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _StickPainter old) => old.origin != origin || old.now != now;
}

class _MiniMapPainter extends CustomPainter {
  final SnakeWorld w;
  _MiniMapPainter(this.w);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFF2E5F).withValues(alpha: 0.7),
    );
    final k = r / SnakeWorld.radius;
    for (final s in w.snakes) {
      if (!s.alive) continue;
      final dot = 1.5 + min(3.0, s.length / 40);
      canvas.drawCircle(
        c + s.head * k,
        s.isPlayer ? dot + 1.5 : dot,
        Paint()..color = s.isPlayer ? Colors.white : _c(s.color).withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => true;
}
