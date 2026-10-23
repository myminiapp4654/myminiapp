import 'dart:math';

import 'package:flutter/material.dart';

import 'stack_game.dart';

/// Qavatga qarab rang (har qavatda biroz o'zgaradi).
double stackHue(int level) => (200 + level * 7.0) % 360;

/// Minora ortidagi fon ranglari (kamera balandligiga qarab).
List<Color> stackBackground(double cam) {
  final hue = stackHue(cam.round());
  return [
    HSLColor.fromAHSL(1, hue, 0.45, 0.30).toColor(),
    HSLColor.fromAHSL(1, (hue + 50) % 360, 0.55, 0.10).toColor(),
  ];
}

/// Izometrik minora.
class StackTowerPainter extends CustomPainter {
  final StackGame g;
  final double cam;
  final bool showMoving;

  /// Aniq qo'yilganda yuqori qavat atrofidagi halqa (0..1).
  final double? ripple;

  StackTowerPainter(this.g, {required this.cam, required this.showMoving, this.ripple});

  static const _h = 2.0; // qavat balandligi
  static final _c = cos(pi / 6), _s = sin(pi / 6);

  late double _k;
  late Offset _origin;

  Offset _iso(double x, double y, double z) =>
      _origin + Offset((x - z) * _c * _k, ((x + z) * _s - y) * _k);

  @override
  void paint(Canvas canvas, Size size) {
    _k = size.width * 0.6 / (StackGame.base * 2 * _c);
    // Minora tepasi ekranning ~45% balandligida
    _origin = Offset(size.width / 2, size.height * 0.5 + cam * _h * _k);

    // Pastda "chuqurlikka" ketuvchi asos ustun
    final base = g.tower.first;
    _box(canvas, StackBox(base.x, base.z, base.w, base.d, -12), 0, heightLevels: 12);

    final topLevel = g.score;
    final behind = <StackPiece>[], front = <StackPiece>[];
    for (final p in g.pieces) {
      final t = g.top;
      final pc = p.box.x + p.box.w / 2 + p.box.z + p.box.d / 2;
      final tc = t.x + t.w / 2 + t.z + t.d / 2;
      (pc < tc ? behind : front).add(p);
    }
    for (final p in behind) {
      _piece(canvas, p);
    }
    // Faqat ko'rinadigan qavatlar
    for (final b in g.tower) {
      if (b.level < topLevel - 14) continue;
      _box(canvas, b, b.level);
    }
    if (showMoving && !g.over) _box(canvas, g.moving, g.moving.level);
    for (final p in front) {
      _piece(canvas, p);
    }

    final r = ripple;
    if (r != null) {
      final t = g.top;
      final grow = 0.4 + r * 2.0;
      final y = (t.level + 1) * _h;
      final path = Path()
        ..addPolygon([
          _iso(t.x - grow, y, t.z - grow),
          _iso(t.x + t.w + grow, y, t.z - grow),
          _iso(t.x + t.w + grow, y, t.z + t.d + grow),
          _iso(t.x - grow, y, t.z + t.d + grow),
        ], true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: (1 - r) * 0.9),
      );
    }
  }

  void _piece(Canvas canvas, StackPiece p) {
    final age = g.time - p.born;
    final fall = 0.5 * 30 * age * age; // erkin tushish
    final alpha = (1 - age / 2.5).clamp(0.0, 1.0);
    _box(canvas, p.box, p.box.level, drop: fall, alpha: alpha);
  }

  /// Bitta blok: tepa va ikki ko'rinadigan yon.
  void _box(Canvas canvas, StackBox b, int colorLevel,
      {double drop = 0, double alpha = 1, int heightLevels = 1}) {
    final hue = stackHue(colorLevel);
    Color c(double l) => HSLColor.fromAHSL(alpha, hue, 0.6, l.clamp(0.0, 1.0)).toColor();
    final y0 = b.level * _h - drop, y1 = y0 + _h * heightLevels;
    final x0 = b.x, x1 = b.x + b.w, z0 = b.z, z1 = b.z + b.d;

    final top = [_iso(x0, y1, z0), _iso(x1, y1, z0), _iso(x1, y1, z1), _iso(x0, y1, z1)];
    final right = [_iso(x1, y1, z0), _iso(x1, y1, z1), _iso(x1, y0, z1), _iso(x1, y0, z0)];
    final left = [_iso(x0, y1, z1), _iso(x1, y1, z1), _iso(x1, y0, z1), _iso(x0, y0, z1)];

    canvas.drawPath(Path()..addPolygon(right, true), Paint()..color = c(0.48));
    canvas.drawPath(Path()..addPolygon(left, true), Paint()..color = c(0.38));
    canvas.drawPath(Path()..addPolygon(top, true), Paint()..color = c(0.64));
    // Yuqori qirralarda nozik yorug' chiziq
    canvas.drawPath(
      Path()..addPolygon(top, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant StackTowerPainter old) => true;
}
