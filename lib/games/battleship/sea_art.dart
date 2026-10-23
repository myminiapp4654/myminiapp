import 'dart:math';

import 'package:flutter/material.dart';

import 'battleship_game.dart';

/// Katak ko'rinishi.
enum CellView { water, ship, hit, sunk, miss, mark }

/// Kema bo'lagi: kemaning nechanchi katagi, uzunligi, yo'nalishi.
class ShipSeg {
  final int index;
  final int length;
  final bool horizontal;
  const ShipSeg(this.index, this.length, this.horizontal);

  static ShipSeg? of(Fleet fleet, int cell) {
    final ship = fleet.shipAt(cell);
    if (ship == null) return null;
    final h = ship.length == 1 || ship.cells[1] - ship.cells[0] == 1;
    return ShipSeg(ship.cells.indexOf(cell), ship.length, h);
  }
}

/// Bitta dengiz katagi: suv, kema bo'lagi, olov, sachrash.
class SeaCellPainter extends CustomPainter {
  final CellView view;
  final ShipSeg? seg;

  /// Sudrash paytidagi ko'rinish: true — mumkin (yashil), false — mumkin emas.
  final bool? preview;
  final bool faded;

  /// Faqat kema (suvsiz) — portdagi va sudralayotgan kemalar uchun.
  final bool water;

  SeaCellPainter(this.view,
      {this.seg, this.preview, this.faded = false, this.water = true});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (water) _water(canvas, r);

    const shipViews = {CellView.ship, CellView.hit, CellView.sunk};
    if (seg != null && shipViews.contains(view)) {
      _ship(canvas, r, seg!, burnt: view == CellView.sunk, faded: faded);
    }

    switch (view) {
      case CellView.hit:
        _fire(canvas, r, strong: true);
      case CellView.sunk:
        _fire(canvas, r, strong: false);
        _cross(canvas, r, const Color(0xFF3E0A0A));
      case CellView.miss:
        _splash(canvas, r, 1);
      case CellView.mark:
        _splash(canvas, r, 0.4);
      default:
        break;
    }

    if (preview != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(4)),
        Paint()
          ..color = (preview! ? const Color(0xFF4CFF8A) : const Color(0xFFFF4D4D))
              .withValues(alpha: 0.55),
      );
    }
  }

  void _water(Canvas canvas, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C6FB0), Color(0xFF0E4A80)],
        ).createShader(r),
    );
    // Mayda to'lqin chizig'i
    final w = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r.width * 0.04
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.12);
    final y = r.top + r.height * 0.62;
    final path = Path()
      ..moveTo(r.left + r.width * 0.2, y)
      ..quadraticBezierTo(r.left + r.width * 0.35, y - r.height * 0.1, r.left + r.width * 0.5, y)
      ..quadraticBezierTo(r.left + r.width * 0.65, y + r.height * 0.1, r.left + r.width * 0.8, y);
    canvas.drawPath(path, w);
  }

  void _ship(Canvas canvas, Rect r, ShipSeg s, {required bool burnt, required bool faded}) {
    final first = s.index == 0, last = s.index == s.length - 1;
    final pad = r.width * 0.12;
    // Kema korpusi kataklar orasida uzilmasligi uchun ichki tomonlar chetgacha
    var body = Rect.fromLTRB(
      s.horizontal ? (first ? r.left + pad : r.left - 1) : r.left + pad,
      s.horizontal ? r.top + pad : (first ? r.top + pad : r.top - 1),
      s.horizontal ? (last ? r.right - pad : r.right + 1) : r.right - pad,
      s.horizontal ? r.bottom - pad : (last ? r.bottom - pad : r.bottom + 1),
    );
    final round = Radius.circular(r.width * 0.42);
    final rr = RRect.fromRectAndCorners(
      body,
      topLeft: first ? round : Radius.zero,
      bottomLeft: (s.horizontal ? first : last) ? round : Radius.zero,
      topRight: (s.horizontal ? last : first) ? round : Radius.zero,
      bottomRight: last ? round : Radius.zero,
    );
    final colors = burnt
        ? const [Color(0xFF5D2A1E), Color(0xFF2A100A)]
        : const [Color(0xFFD5DEE6), Color(0xFF7D8E9C), Color(0xFF52626F)];
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.black.withValues(alpha: faded ? 0.1 : 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: s.horizontal ? Alignment.topCenter : Alignment.centerLeft,
          end: s.horizontal ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [
            for (final c in colors) faded ? c.withValues(alpha: 0.35) : c,
          ],
        ).createShader(body),
    );
    if (burnt) return;
    // Paluba: o'rtadagi chiziq va minora
    final deck = Paint()
      ..color = const Color(0xFF3C4A55).withValues(alpha: faded ? 0.3 : 0.9)
      ..strokeWidth = r.width * 0.06
      ..strokeCap = StrokeCap.round;
    final c = r.center;
    if (s.horizontal) {
      canvas.drawLine(Offset(body.left + 3, c.dy), Offset(body.right - 3, c.dy), deck);
    } else {
      canvas.drawLine(Offset(c.dx, body.top + 3), Offset(c.dx, body.bottom - 3), deck);
    }
    if (!first && !last || s.length == 1) {
      canvas.drawCircle(c, r.width * 0.16,
          Paint()..color = const Color(0xFF8FA3B2).withValues(alpha: faded ? 0.3 : 1));
      canvas.drawCircle(c, r.width * 0.07,
          Paint()..color = const Color(0xFF3C4A55).withValues(alpha: faded ? 0.3 : 1));
    }
  }

  void _fire(Canvas canvas, Rect r, {required bool strong}) {
    final c = r.center;
    canvas.drawCircle(
      c,
      r.width * (strong ? 0.5 : 0.38),
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFF59D),
          const Color(0xFFFF9800),
          const Color(0xFFE53935).withValues(alpha: strong ? 0.9 : 0.5),
          const Color(0x00E53935),
        ], stops: const [0, 0.3, 0.65, 1])
            .createShader(Rect.fromCircle(center: c, radius: r.width * 0.5)),
    );
    if (strong) _cross(canvas, r, const Color(0xFF7A0000));
  }

  void _cross(Canvas canvas, Rect r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = r.width * 0.1
      ..strokeCap = StrokeCap.round;
    final d = r.width * 0.2;
    final c = r.center;
    canvas.drawLine(c - Offset(d, d), c + Offset(d, d), p);
    canvas.drawLine(c + Offset(d, -d), c - Offset(d, -d), p);
  }

  void _splash(Canvas canvas, Rect r, double strength) {
    final c = r.center;
    canvas.drawCircle(
      c,
      r.width * 0.28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.05
        ..color = Colors.white.withValues(alpha: 0.45 * strength),
    );
    canvas.drawCircle(c, r.width * 0.1, Paint()..color = Colors.white.withValues(alpha: 0.85 * strength));
  }

  @override
  bool shouldRepaint(covariant SeaCellPainter old) =>
      old.view != view ||
      old.preview != preview ||
      old.faded != faded ||
      old.seg?.index != seg?.index ||
      old.seg?.length != seg?.length ||
      old.seg?.horizontal != seg?.horizontal;
}

/// Otish effekti: sachrash yoki portlash (bir marta o'ynaydi).
class ShotEffect extends StatelessWidget {
  final bool hit;
  const ShotEffect({super.key, required this.hit});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        builder: (_, t, _) => CustomPaint(painter: _ShotPainter(t, hit)),
      ),
    );
  }
}

class _ShotPainter extends CustomPainter {
  final double t;
  final bool hit;
  _ShotPainter(this.t, this.hit);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final color = hit ? const Color(0xFFFF7043) : Colors.white;
    canvas.drawCircle(
      c,
      r * (0.3 + t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t)
        ..color = color.withValues(alpha: 1 - t),
    );
    for (var k = 0; k < 8; k++) {
      final a = k * pi / 4 + 0.3;
      final p = c + Offset(cos(a), sin(a)) * r * (0.2 + t * 0.9);
      canvas.drawCircle(
          p, 3 * (1 - t), Paint()..color = (hit ? const Color(0xFFFFD54F) : Colors.white).withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant _ShotPainter old) => old.t != t;
}

/// 9×9 dengiz taxtasi: harflar va raqamlar bilan.
class SeaGrid extends StatelessWidget {
  final String keyPrefix;
  final (CellView, ShipSeg?) Function(int i) cell;
  final void Function(int i)? onTap;
  final bool small;

  /// Oxirgi otilgan katak (effekt uchun) va natijasi.
  final int? effectCell;
  final bool effectHit;
  final int effectId;

  const SeaGrid({
    super.key,
    required this.keyPrefix,
    required this.cell,
    this.onTap,
    this.small = false,
    this.effectCell,
    this.effectHit = false,
    this.effectId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      fontSize: small ? 9 : 12,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF9BD8FF),
    );
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: EdgeInsets.all(small ? 3 : 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(small ? 10 : 16),
          color: const Color(0xFF062646),
          border: Border.all(color: const Color(0xFF4FD1FF).withValues(alpha: 0.4)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: LayoutBuilder(builder: (context, box) {
          final s = box.maxWidth / (kBoardSize + 1);
          return Stack(
            children: [
              for (var c = 0; c < kBoardSize; c++)
                Positioned(
                  left: (c + 1) * s,
                  top: 0,
                  width: s,
                  height: s,
                  child: Center(child: Text('abcdefghi'[c], style: label)),
                ),
              for (var r = 0; r < kBoardSize; r++)
                Positioned(
                  left: 0,
                  top: (r + 1) * s,
                  width: s,
                  height: s,
                  child: Center(child: Text('${r + 1}', style: label)),
                ),
              for (var i = 0; i < kCells; i++)
                Positioned(
                  left: (i % kBoardSize + 1) * s,
                  top: (i ~/ kBoardSize + 1) * s,
                  width: s,
                  height: s,
                  child: GestureDetector(
                    key: ValueKey('$keyPrefix-$i'),
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: Builder(builder: (_) {
                      final (view, seg) = cell(i);
                      return CustomPaint(painter: SeaCellPainter(view, seg: seg));
                    }),
                  ),
                ),
              // Katak chiziqlari
              Positioned(
                left: s,
                top: s,
                width: s * kBoardSize,
                height: s * kBoardSize,
                child: IgnorePointer(child: CustomPaint(painter: _GridLines())),
              ),
              if (effectCell != null)
                Positioned(
                  key: ValueKey('fx-$effectId'),
                  left: (effectCell! % kBoardSize + 1) * s - s,
                  top: (effectCell! ~/ kBoardSize + 1) * s - s,
                  width: s * 3,
                  height: s * 3,
                  child: ShotEffect(hit: effectHit),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _GridLines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF9BD8FF).withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final s = size.width / kBoardSize;
    for (var k = 0; k <= kBoardSize; k++) {
      canvas.drawLine(Offset(k * s, 0), Offset(k * s, size.height), p);
      canvas.drawLine(Offset(0, k * s), Offset(size.width, k * s), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
