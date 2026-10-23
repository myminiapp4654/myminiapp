import 'dart:math';

import 'package:flutter/material.dart';

import '../games/chess/chess_pieces.dart';
import 'crown.dart';

/// Bosh ekrandagi o'yin kartochkalari uchun kichik rasmlar.
enum GameArt { xo, chess, checkers, battleship, snakes, maze, snake, chain, stack, walls }

class GameArtPainter extends CustomPainter {
  final GameArt art;
  final double t; // 0..1 sekin animatsiya
  GameArtPainter(this.art, [this.t = 0]);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    switch (art) {
      case GameArt.xo:
        _xo(canvas, s);
      case GameArt.chess:
        _chess(canvas, s);
      case GameArt.checkers:
        _checkers(canvas, s);
      case GameArt.battleship:
        _ship(canvas, s);
      case GameArt.snakes:
        _snakes(canvas, s);
      case GameArt.maze:
        _maze(canvas, s);
      case GameArt.snake:
        _neonSnake(canvas, s);
      case GameArt.chain:
        _chain(canvas, s);
      case GameArt.stack:
        _stack(canvas, s);
      case GameArt.walls:
        _walls(canvas, s);
    }
    canvas.restore();
  }

  static Paint _ball(Offset c, double r, Color color) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      colors: [Color.lerp(color, Colors.white, 0.6)!, color, Color.lerp(color, Colors.black, 0.4)!],
      stops: const [0, 0.5, 1],
    ).createShader(Rect.fromCircle(center: c, radius: r));

  void _xo(Canvas c, double s) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    for (var k = 1; k < 3; k++) {
      c.drawLine(Offset(s * (0.15 + 0.233 * k), s * 0.12), Offset(s * (0.15 + 0.233 * k), s * 0.88), line);
      c.drawLine(Offset(s * 0.12, s * (0.15 + 0.233 * k)), Offset(s * 0.88, s * (0.15 + 0.233 * k)), line);
    }
    final x = Paint()
      ..color = const Color(0xFF5CE1E6)
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    void drawX(double cx, double cy) {
      final d = s * 0.075;
      c.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), x);
      c.drawLine(Offset(cx + d, cy - d), Offset(cx - d, cy + d), x);
    }

    final o = Paint()
      ..color = const Color(0xFFFF6B9A)
      ..strokeWidth = s * 0.055
      ..style = PaintingStyle.stroke;
    drawX(s * 0.27, s * 0.27);
    drawX(s * 0.5, s * 0.5);
    drawX(s * 0.73, s * 0.73);
    c.drawCircle(Offset(s * 0.73, s * 0.27), s * 0.08, o);
    c.drawCircle(Offset(s * 0.27, s * 0.73), s * 0.08, o);
    // Yutgan chiziq
    c.drawLine(
        Offset(s * 0.17, s * 0.17),
        Offset(s * (0.17 + 0.66 * t.clamp(0, 1)), s * (0.17 + 0.66 * t.clamp(0, 1))),
        Paint()
          ..color = Colors.white
          ..strokeWidth = s * 0.025
          ..strokeCap = StrokeCap.round);
  }

  void _chess(Canvas c, double s) {
    final cell = s * 0.8 / 4;
    final o = s * 0.1;
    for (var r = 0; r < 4; r++) {
      for (var k = 0; k < 4; k++) {
        c.drawRect(
          Rect.fromLTWH(o + k * cell, o + r * cell, cell, cell),
          Paint()..color = (r + k).isEven ? const Color(0xFFEED9B6) : const Color(0xFFB07A4A),
        );
      }
    }
    // Vektor ot (shriftga bog'liq emas)
    c.save();
    c.translate(s * 0.14, s * 0.1);
    ChessPiecePainter('N').paint(c, Size(s * 0.72, s * 0.72));
    c.restore();
  }

  void _checkers(Canvas c, double s) {
    void disc(Offset p, Color color, double r, bool king) {
      c.drawCircle(p + Offset(0, r * 0.18), r, Paint()..color = Colors.black45);
      c.drawCircle(p, r, _ball(p, r, color));
      c.drawCircle(p, r * 0.72, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = Colors.white24);
      if (king) {
        paintCrown(c, Rect.fromCenter(center: p, width: r * 1.1, height: r * 0.9));
      }
    }

    disc(Offset(s * 0.36, s * 0.62), const Color(0xFF222222), s * 0.24, false);
    disc(Offset(s * 0.62, s * 0.4), const Color(0xFFD32F2F), s * 0.24, true);
  }

  void _ship(Canvas c, double s) {
    // To'lqinlar
    final wave = Paint()
      ..color = const Color(0xFF4FD1FF).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 3; row++) {
      final path = Path();
      final y = s * (0.66 + row * 0.1);
      path.moveTo(s * 0.05, y);
      for (var x = 0.05; x < 0.95; x += 0.15) {
        path.quadraticBezierTo(s * (x + 0.04), y - s * 0.05 + sin(t * 2 * pi + row) * s * 0.01,
            s * (x + 0.075), y);
        path.quadraticBezierTo(s * (x + 0.11), y + s * 0.05, s * (x + 0.15), y);
      }
      c.drawPath(path, wave..color = wave.color.withValues(alpha: 0.6 - row * 0.15));
    }
    // Kema korpusi
    final bob = sin(t * 2 * pi) * s * 0.015;
    final hull = Path()
      ..moveTo(s * 0.12, s * 0.5 + bob)
      ..lineTo(s * 0.88, s * 0.5 + bob)
      ..lineTo(s * 0.76, s * 0.66 + bob)
      ..lineTo(s * 0.22, s * 0.66 + bob)
      ..close();
    c.drawPath(hull, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFF455A64)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, s * 0.5, s, s * 0.16)));
    c.drawRect(Rect.fromLTWH(s * 0.36, s * 0.36 + bob, s * 0.26, s * 0.14), Paint()..color = const Color(0xFFCFD8DC));
    c.drawRect(Rect.fromLTWH(s * 0.46, s * 0.24 + bob, s * 0.07, s * 0.12), Paint()..color = const Color(0xFFFF7043));
    // Portlash
    final boom = Offset(s * 0.8, s * 0.26);
    c.drawCircle(boom, s * 0.11, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFF7043), Color(0x00FF7043)])
          .createShader(Rect.fromCircle(center: boom, radius: s * 0.11)));
  }

  void _snakes(Canvas c, double s) {
    // O't taxta
    final q = s * 0.8 / 5;
    for (var r = 0; r < 5; r++) {
      for (var k = 0; k < 5; k++) {
        c.drawRect(
          Rect.fromLTWH(s * 0.1 + k * q, s * 0.1 + r * q, q, q),
          Paint()..color = (r + k).isEven ? const Color(0xFF8BC34A) : const Color(0xFF7CB342),
        );
      }
    }
    // Narvon
    final a = Offset(s * 0.28, s * 0.84), b = Offset(s * 0.42, s * 0.2);
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / d.distance * s * 0.05;
    final wood = Paint()
      ..color = const Color(0xFFA0642C)
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round;
    c.drawLine(a + n, b + n, wood);
    c.drawLine(a - n, b - n, wood);
    for (var k = 1; k < 8; k++) {
      final p = Offset.lerp(a, b, k / 8)!;
      c.drawLine(p - n, p + n, wood..color = const Color(0xFFD7A15F));
    }
    // Ilon (to'lqinli, asta tebranadi)
    final body = <Offset>[];
    for (var k = 0; k <= 60; k++) {
      final t = k / 60;
      final x = s * (0.72 - 0.12 * t) + sin(t * pi * 3 + this.t * pi * 2) * s * 0.07;
      final y = s * (0.18 + 0.66 * t);
      body.add(Offset(x, y));
    }
    for (var k = body.length - 1; k >= 0; k--) {
      final w = s * (0.075 - 0.05 * k / 60);
      c.drawCircle(body[k], w + s * 0.01, Paint()..color = const Color(0xFF8E1B1B));
    }
    for (var k = body.length - 1; k >= 0; k--) {
      final w = s * (0.075 - 0.05 * k / 60);
      c.drawCircle(body[k], w, Paint()..color = (k ~/ 6).isOdd ? const Color(0xFFFFEB3B) : const Color(0xFFE53935));
    }
    final h = body.first;
    c.drawCircle(h, s * 0.085, Paint()..color = const Color(0xFFE53935));
    for (final side in const [-1.0, 1.0]) {
      final e = h + Offset(side * s * 0.035, -s * 0.02);
      c.drawCircle(e, s * 0.022, Paint()..color = Colors.white);
      c.drawCircle(e + Offset(0, -s * 0.005), s * 0.011, Paint()..color = Colors.black);
    }
    // Zar
    final die = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(s * 0.27, s * 0.3), width: s * 0.2, height: s * 0.2), Radius.circular(s * 0.04));
    c.drawRRect(die.shift(Offset(s * 0.01, s * 0.015)), Paint()..color = Colors.black38);
    c.drawRRect(die, Paint()..color = Colors.white);
    for (final o in const [Offset(-1, -1), Offset(1, 1), Offset(0, 0)]) {
      c.drawCircle(die.center + o * s * 0.05, s * 0.017, Paint()..color = const Color(0xFF1A1A2E));
    }
  }

  void _maze(Canvas c, double s) {
    // Kichik qo'lda chizilgan labirint (9×9)
    const rows = [
      '####.####',
      '#.....#.#',
      '#.###.#.#',
      '#...#...#',
      '###.###.#',
      '#.#...#.#',
      '#.###.#.#',
      '#.....#.#',
      '######.##',
    ];
    final q = s * 0.84 / 9;
    final o = s * 0.08;
    c.drawRect(Rect.fromLTWH(o, o, q * 9, q * 9), Paint()..color = const Color(0xFF0E0B0A));
    for (var r = 0; r < 9; r++) {
      for (var k = 0; k < 9; k++) {
        if (rows[r][k] != '#') continue;
        final rect = Rect.fromLTWH(o + k * q, o + r * q, q + 0.5, q + 0.5);
        c.drawRect(rect, Paint()..color = const Color(0xFF9A4F2C));
        c.drawRect(Rect.fromLTWH(rect.left, rect.top, q, q * 0.2), Paint()..color = const Color(0xFFC0703F));
      }
    }
    // Chizilayotgan yo'l
    const route = [(0, 4), (1, 4), (1, 5), (2, 5), (3, 5), (3, 6), (3, 7), (4, 7), (5, 7), (6, 7), (7, 7)];
    final shown = (route.length * (0.35 + 0.65 * t)).ceil().clamp(2, route.length);
    final path = Path();
    for (var k = 0; k < shown; k++) {
      final (r, col) = route[k];
      final p = Offset(o + (col + 0.5) * q, o + (r + 0.5) * q);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = q * 0.45
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFC233),
    );
    final (hr, hc) = route[shown - 1];
    c.drawCircle(Offset(o + (hc + 0.5) * q, o + (hr + 0.5) * q), q * 0.32, Paint()..color = Colors.white);
  }

  void _neonSnake(Canvas c, double s) {
    c.drawRect(Rect.fromLTWH(s * 0.06, s * 0.06, s * 0.88, s * 0.88), Paint()..color = const Color(0xFF05040B));
    // Ozuqa
    const foodColors = [Color(0xFFFF2E97), Color(0xFFB4FF39), Color(0xFFFFE53B), Color(0xFFB967FF)];
    final rnd = Random(3);
    for (var k = 0; k < 16; k++) {
      final p = Offset(s * (0.12 + rnd.nextDouble() * 0.76), s * (0.12 + rnd.nextDouble() * 0.76));
      final col = foodColors[k % foodColors.length];
      c.drawCircle(p, s * 0.022, Paint()..color = col.withValues(alpha: 0.25));
      c.drawCircle(p, s * 0.011, Paint()..color = col);
    }
    // Ilon (sekin to'lqinlanadi)
    const color = Color(0xFF00F5FF);
    final pts = <Offset>[
      for (var k = 0; k <= 40; k++)
        Offset(
          s * (0.18 + 0.64 * k / 40),
          s * (0.55 + 0.16 * sin(k / 40 * pi * 2.2 + t * pi * 2)),
        ),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.12
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03),
    );
    for (var k = 0; k < pts.length; k++) {
      c.drawCircle(pts[k], s * 0.045, Paint()..color = (k ~/ 4).isEven ? color : const Color(0xFF008C93));
    }
    final h = pts.last;
    c.drawCircle(h, s * 0.055, Paint()..color = color);
    for (final dy in const [-1.0, 1.0]) {
      final e = h + Offset(s * 0.015, dy * s * 0.025);
      c.drawCircle(e, s * 0.02, Paint()..color = Colors.white);
      c.drawCircle(e + Offset(s * 0.007, 0), s * 0.01, Paint()..color = Colors.black);
    }
  }

  void _chain(Canvas c, double s) {
    const colors = [Color(0xFFFF4D8D), Color(0xFF40C4FF)];
    final cell = s * 0.8 / 3;
    for (var r = 0; r < 3; r++) {
      for (var k = 0; k < 3; k++) {
        final rect = Rect.fromLTWH(s * 0.1 + k * cell, s * 0.1 + r * cell, cell, cell);
        c.drawRect(rect, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF4D8D).withValues(alpha: 0.5));
        final n = (r * 3 + k) % 4;
        final color = colors[(r + k) % 2];
        for (var i = 0; i < min(n, 3); i++) {
          final a = i * 2 * pi / max(n, 1) + t * 2 * pi;
          final p = rect.center + Offset(cos(a), sin(a)) * (n == 1 ? 0 : cell * 0.16);
          c.drawCircle(p, cell * 0.16, _ball(p, cell * 0.16, color));
        }
      }
    }
    // Portlash halqasi
    final center = Offset(s * 0.5, s * 0.5);
    c.drawCircle(center, cell * (0.4 + t * 0.5), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - t)
      ..color = Colors.white.withValues(alpha: 1 - t));
  }

  void _stack(Canvas c, double s) {
    // Izometrik minora: pastdan yuqoriga toraygan bloklar
    final k = s * 0.034;
    final cx = s * 0.5;
    final c30 = cos(pi / 6), s30 = sin(pi / 6);
    Offset iso(double x, double y, double z, double baseY) =>
        Offset(cx + (x - z) * c30 * k, baseY + ((x + z) * s30 - y) * k);
    const levels = 6;
    var w = 10.0, d = 10.0, x = -5.0, z = -5.0;
    final shift = sin(t * pi * 2) * 3; // tepadagi suzayotgan blok
    for (var lv = 0; lv < levels; lv++) {
      final moving = lv == levels - 1;
      final bx = moving ? x + shift : x;
      final hue = (200 + lv * 18.0) % 360;
      Color col(double l) => HSLColor.fromAHSL(1, hue, 0.6, l).toColor();
      final y0 = lv * 2.0, y1 = y0 + 2.0;
      final baseY = s * 0.7;
      final top = [iso(bx, y1, z, baseY), iso(bx + w, y1, z, baseY), iso(bx + w, y1, z + d, baseY), iso(bx, y1, z + d, baseY)];
      final right = [iso(bx + w, y1, z, baseY), iso(bx + w, y1, z + d, baseY), iso(bx + w, y0, z + d, baseY), iso(bx + w, y0, z, baseY)];
      final left = [iso(bx, y1, z + d, baseY), iso(bx + w, y1, z + d, baseY), iso(bx + w, y0, z + d, baseY), iso(bx, y0, z + d, baseY)];
      c.drawPath(Path()..addPolygon(right, true), Paint()..color = col(0.48));
      c.drawPath(Path()..addPolygon(left, true), Paint()..color = col(0.38));
      c.drawPath(Path()..addPolygon(top, true), Paint()..color = col(0.64));
      // Har qavatda biroz torayadi
      if (lv.isEven) {
        x += 0.8;
        w -= 1.2;
      } else {
        z += 0.6;
        d -= 1.0;
      }
    }
  }

  void _walls(Canvas c, double s) {
    final bw = s * 0.26, bh = s * 0.13;
    for (var r = 0; r < 6; r++) {
      for (var k = -1; k < 4; k++) {
        final x = s * 0.06 + k * bw + (r.isOdd ? bw / 2 : 0);
        final rect = Rect.fromLTWH(x, s * 0.1 + r * bh, bw - 3, bh - 3);
        if ((r == 2 || r == 3) && (k == 1 || k == 2)) continue; // teshik
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFFD2694A), const Color(0xFF8E3B26)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect));
      }
    }
    // Teshikdan nur
    final hole = Rect.fromLTWH(s * 0.32, s * 0.36, s * 0.42, s * 0.26);
    c.drawRect(hole, Paint()
      ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9 - t * 0.3), const Color(0x00FFB347)])
          .createShader(hole.inflate(20)));
  }

  @override
  bool shouldRepaint(covariant GameArtPainter old) => old.t != t || old.art != art;
}
