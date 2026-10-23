import 'dart:math';

import 'package:flutter/material.dart';

import 'snakes_game.dart';

/// Barcha o'lchamlar "katak birligida": 1 = bitta katak tomoni.
/// Chizishda katak o'lchamiga ko'paytiriladi.

/// Katak markazi (katak birligida). 0 — taxtaga chiqmagan: 1-katakda turadi.
Offset cellCenter(int n) {
  final (row, col) = SnakesGame.cellRC(max(n, 1));
  return Offset(col + 0.5, SnakesGame.size - 1 - row + 0.5);
}

/// Ilon tanasidagi nuqta: t=0 — bosh, t=1 — dum.
Offset snakePoint(int head, int tail, SnakeLook look, double t) {
  final h = cellCenter(head), e = cellCenter(tail);
  final d = e - h;
  final len = d.distance;
  final n = Offset(-d.dy, d.dx) / len;
  final bend = look.bend * len * 0.12 * sin(pi * t);
  final wave = look.wiggle * 2.2 * sin(pi * look.waves * t) * (1 - 0.35 * t);
  return h + d * t + n * (bend + wave);
}

/// Narvon bo'ylab nuqta: t=0 — pastki uchi, t=1 — tepasi.
Offset ladderPoint(int bottom, int top, double t) =>
    Offset.lerp(cellCenter(bottom), cellCenter(top), t)!;

const kSnakeColors = [
  (Color(0xFF66BB6A), Color(0xFFFFEB3B)), // yashil, sariq yo'l
  (Color(0xFFEF5350), Color(0xFFFFFFFF)), // qizil, oq
  (Color(0xFF42A5F5), Color(0xFF0D47A1)), // ko'k
  (Color(0xFFAB47BC), Color(0xFFF8BBD0)), // binafsha, pushti
  (Color(0xFFFFA726), Color(0xFF6D4C41)), // to'q sariq, jigarrang
  (Color(0xFF26C6DA), Color(0xFF1A237E)), // moviy
];

/// Taxta: o't kataklar, raqamlar, narvonlar va ilonlar.
class SnakesBoardPainter extends CustomPainter {
  final SnakesGame game;

  /// Raqamlar uchun asosiy matn uslubi (ilova shrifti).
  final TextStyle text;
  SnakesBoardPainter(this.game, this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / SnakesGame.size;
    _cells(canvas, s);
    // Qayerga tushsa nima bo'lishi: narvon pasti — yashil, ilon boshi — qizil katak
    for (final n in game.ladders.keys) {
      _mark(canvas, s, n, const Color(0xFF00E676));
    }
    for (final n in game.snakes.keys) {
      _mark(canvas, s, n, const Color(0xFFFF1744));
    }
    for (final e in game.ladders.entries) {
      _ladder(canvas, s, e.key, e.value);
    }
    for (final e in game.snakes.entries) {
      _snake(canvas, s, e.key, e.value, game.looks[e.key]!);
    }
  }

  void _cells(Canvas canvas, double s) {
    const a = Color(0xFF8BC34A), b = Color(0xFF7CB342);
    for (var n = 1; n <= SnakesGame.last; n++) {
      final c = cellCenter(n) * s;
      final rect = Rect.fromCenter(center: c, width: s, height: s);
      final (row, col) = SnakesGame.cellRC(n);
      canvas.drawRect(rect, Paint()..color = (row + col).isEven ? a : b);
      // O't tuklari
      final grass = Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..strokeWidth = s * 0.025
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        final x = rect.left + s * (0.25 + 0.25 * k),
            y = rect.bottom - s * (0.18 + 0.06 * (k % 2));
        canvas.drawLine(Offset(x, y), Offset(x - s * 0.04, y - s * 0.1), grass);
        canvas.drawLine(Offset(x, y), Offset(x + s * 0.04, y - s * 0.1), grass);
      }
      // Raqam
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: text.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: s * 0.26,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + Offset(s * 0.07, s * 0.04));
    }
    // 100 — yulduz
    _star(
      canvas,
      cellCenter(SnakesGame.last) * s + Offset(0, s * 0.08),
      s * 0.28,
    );
  }

  void _mark(Canvas canvas, double s, int n, Color color) {
    final rect = Rect.fromCenter(center: cellCenter(n) * s, width: s, height: s).deflate(s * 0.06);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.18));
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.28));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..color = color.withValues(alpha: 0.85),
    );
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final a = -pi / 2 + k * pi / 5;
      final rr = k.isEven ? r : r * 0.45;
      final p = c + Offset(cos(a), sin(a)) * rr;
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path.shift(Offset(0, r * 0.12)),
      Paint()..color = Colors.black26,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF59D), Color(0xFFFFB300)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xFFE65100),
    );
  }

  void _ladder(Canvas canvas, double s, int bottom, int top) {
    final p0 = cellCenter(bottom) * s, p1 = cellCenter(top) * s;
    final d = p1 - p0;
    final len = d.distance;
    final u = d / len;
    final n = Offset(-u.dy, u.dx);
    // Uchlari katakdan biroz chiqib turadi
    final a = p0 - u * s * 0.18, b = p1 + u * s * 0.18;
    final gap = s * 0.2;
    final rail = s * 0.085;

    void draw(Offset shift, Paint railPaint, Paint rungPaint) {
      for (final side in const [-1.0, 1.0]) {
        canvas.drawLine(
          a + n * gap * side + shift,
          b + n * gap * side + shift,
          railPaint,
        );
      }
      final total = (b - a).distance;
      for (var x = s * 0.22; x < total - s * 0.12; x += s * 0.34) {
        final c = a + u * x + shift;
        canvas.drawLine(c - n * gap, c + n * gap, rungPaint);
      }
    }

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = rail
      ..strokeCap = StrokeCap.round;
    draw(Offset(s * 0.06, s * 0.08), shadow, shadow);
    final rungs = Paint()
      ..color = const Color(0xFFD7A15F)
      ..strokeWidth = rail * 0.8
      ..strokeCap = StrokeCap.round;
    final rails = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF8D5524), Color(0xFFC68642), Color(0xFF8D5524)],
      ).createShader(Rect.fromPoints(a - n * gap, b + n * gap))
      ..strokeWidth = rail
      ..strokeCap = StrokeCap.round;
    draw(Offset.zero, rungs, rails);
    // Relslarga yorug'lik chizig'i
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = rail * 0.25
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      final o = n * (gap * side - rail * 0.2);
      canvas.drawLine(a + o, b + o, shine);
    }
  }

  void _snake(Canvas canvas, double s, int head, int tail, SnakeLook look) {
    final (body, stripe) = kSnakeColors[look.color % kSnakeColors.length];
    final dark = Color.lerp(body, Colors.black, 0.45)!;
    const steps = 140;
    Offset at(double t) => snakePoint(head, tail, look, t) * s;
    double width(double t) => s * (0.26 - 0.18 * t);

    // Soya (bitta qatlamda, ustma-ust tushgan doiralar qoraymasin)
    canvas.saveLayer(
      null,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    for (var k = steps; k >= 0; k -= 2) {
      final t = k / steps;
      canvas.drawCircle(
        at(t) + Offset(s * 0.06, s * 0.08),
        width(t) / 2,
        Paint(),
      );
    }
    canvas.restore();
    // Hoshiya va tana (dumdan boshga, bosh ustida bo'lsin)
    for (var k = steps; k >= 0; k--) {
      final t = k / steps;
      canvas.drawCircle(at(t), width(t) / 2 + s * 0.025, Paint()..color = dark);
    }
    for (var k = steps; k >= 0; k--) {
      final t = k / steps;
      final band = look.pattern == 0 && (t * 14).floor().isOdd && t > 0.08;
      canvas.drawCircle(
        at(t),
        width(t) / 2,
        Paint()..color = band ? stripe : body,
      );
    }
    // Xol-xol naqsh
    if (look.pattern == 1) {
      for (var k = 12; k < steps - 4; k += 9) {
        final t = k / steps;
        canvas.drawCircle(at(t), width(t) * 0.18, Paint()..color = stripe);
      }
    }
    // Yaltirash
    for (var k = steps; k >= 6; k -= 2) {
      final t = k / steps;
      final dir = at(t - 0.01) - at(t);
      final len = dir.distance;
      if (len == 0) continue;
      final nrm = Offset(-dir.dy, dir.dx) / len;
      canvas.drawCircle(
        at(t) + nrm * width(t) * 0.22,
        width(t) * 0.12,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }

    // Bosh
    final h = at(0);
    final fwd = h - at(0.04);
    final ang = atan2(fwd.dy, fwd.dx);
    canvas.save();
    canvas.translate(h.dx, h.dy);
    canvas.rotate(ang);
    final hw = s * 0.36, hl = s * 0.44;
    // Til
    final tongue = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tip = Offset(hl * 0.78, 0);
    canvas.drawLine(Offset(hl * 0.35, 0), tip, tongue);
    canvas.drawLine(tip, tip + Offset(s * 0.07, -s * 0.05), tongue);
    canvas.drawLine(tip, tip + Offset(s * 0.07, s * 0.05), tongue);
    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: hl,
      height: hw,
    );
    canvas.drawOval(headRect.inflate(s * 0.025), Paint()..color = dark);
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.2, -0.3),
          colors: [Color.lerp(body, Colors.white, 0.35)!, body],
        ).createShader(headRect),
    );
    // Ko'zlar
    for (final side in const [-1.0, 1.0]) {
      final e = Offset(hl * 0.12, side * hw * 0.24);
      canvas.drawCircle(e, s * 0.085, Paint()..color = Colors.white);
      canvas.drawCircle(
        e + Offset(s * 0.025, 0),
        s * 0.045,
        Paint()..color = Colors.black,
      );
      canvas.drawCircle(
        e + Offset(s * 0.035, -s * 0.015),
        s * 0.014,
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SnakesBoardPainter old) => old.game != game;
}
