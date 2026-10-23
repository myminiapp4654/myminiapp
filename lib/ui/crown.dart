import 'package:flutter/material.dart';

/// Oltin toj (shashka damkasi va boshqa joylar uchun) — vektor rasm.
void paintCrown(Canvas canvas, Rect r, {Color color = const Color(0xFFFFC94D)}) {
  final w = r.width, h = r.height;
  final path = Path()
    ..moveTo(r.left + w * 0.1, r.top + h * 0.78)
    ..lineTo(r.left + w * 0.04, r.top + h * 0.3)
    ..lineTo(r.left + w * 0.3, r.top + h * 0.52)
    ..lineTo(r.left + w * 0.5, r.top + h * 0.12)
    ..lineTo(r.left + w * 0.7, r.top + h * 0.52)
    ..lineTo(r.left + w * 0.96, r.top + h * 0.3)
    ..lineTo(r.left + w * 0.9, r.top + h * 0.78)
    ..close();
  canvas.drawPath(
    path.shift(Offset(0, h * 0.04)),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, 0.5)!, color, Color.lerp(color, Colors.brown, 0.5)!],
      ).createShader(r),
  );
  final band = Rect.fromLTRB(r.left + w * 0.1, r.top + h * 0.72, r.right - w * 0.1, r.top + h * 0.9);
  canvas.drawRRect(
    RRect.fromRectAndRadius(band, Radius.circular(h * 0.05)),
    Paint()..color = Color.lerp(color, Colors.brown, 0.3)!,
  );
  for (final x in [0.04, 0.5, 0.96]) {
    final y = x == 0.5 ? 0.12 : 0.3;
    canvas.drawCircle(Offset(r.left + w * x, r.top + h * y), w * 0.06, Paint()..color = Colors.white);
  }
}

class CrownPainter extends CustomPainter {
  final Color color;
  CrownPainter([this.color = const Color(0xFFFFC94D)]);

  @override
  void paint(Canvas canvas, Size size) => paintCrown(canvas, Offset.zero & size, color: color);

  @override
  bool shouldRepaint(covariant CrownPainter old) => old.color != color;
}
