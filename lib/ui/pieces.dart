import 'package:flutter/material.dart';

/// Shashka shaklidagi o'yin toshi (Ludo, Ilon va narvon).
class PawnPainter extends CustomPainter {
  final Color color;
  final bool highlight;
  PawnPainter(this.color, {this.highlight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final light = Color.lerp(color, Colors.white, 0.55)!;

    // Soya
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.92), width: w * 0.78, height: h * 0.14),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    // Asos
    final base = Rect.fromCenter(center: Offset(cx, h * 0.84), width: w * 0.8, height: h * 0.2);
    canvas.drawOval(base, Paint()..shader = LinearGradient(colors: [color, dark]).createShader(base));
    // Tana
    final body = Path()
      ..moveTo(cx - w * 0.36, h * 0.84)
      ..quadraticBezierTo(cx - w * 0.3, h * 0.55, cx - w * 0.12, h * 0.42)
      ..lineTo(cx + w * 0.12, h * 0.42)
      ..quadraticBezierTo(cx + w * 0.3, h * 0.55, cx + w * 0.36, h * 0.84)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [light, color, dark],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromLTWH(0, h * 0.4, w, h * 0.45)),
    );
    // Bosh
    final head = Offset(cx, h * 0.3);
    final r = w * 0.27;
    canvas.drawCircle(
      head,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Colors.white, light, color, dark],
          stops: const [0, 0.2, 0.6, 1],
        ).createShader(Rect.fromCircle(center: head, radius: r)),
    );
    // Oq hoshiya
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlight ? w * 0.08 : w * 0.05
      ..color = highlight ? Colors.white : Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(head, r, outline);
    canvas.drawPath(body, outline);
  }

  @override
  bool shouldRepaint(covariant PawnPainter old) =>
      old.color != color || old.highlight != highlight;
}


/// 3D ko'rinishdagi zar.
class Dice3D extends StatelessWidget {
  final int value;
  final double turns;
  final Color color;
  final bool glowing;

  const Dice3D({
    super.key,
    required this.value,
    required this.turns,
    required this.color,
    required this.glowing,
  });

  static const _dots = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (0, 2), (2, 0), (2, 2)],
    5: [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
    6: [(0, 0), (1, 0), (2, 0), (0, 2), (1, 2), (2, 2)],
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: turns,
      duration: const Duration(milliseconds: 60),
      child: Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFE6E6EE), Color(0xFFBFC0CC)],
          ),
          border: Border.all(color: glowing ? Colors.white : Colors.white54, width: 2),
          boxShadow: [
            BoxShadow(
              color: glowing ? color.withValues(alpha: 0.9) : Colors.black54,
              blurRadius: glowing ? 18 : 8,
              spreadRadius: glowing ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            for (final (r, c) in _dots[value]!)
              Align(
                alignment: Alignment(c - 1.0, r - 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value == 1 ? const Color(0xFFE53935) : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
