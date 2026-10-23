import 'package:flutter/material.dart';

/// Shaxmat donalari — vektor rasmlar (shriftga bog'liq emas).
/// [piece]: 'K Q R B N P' (oq) yoki 'k q r b n p' (qora).
class ChessPiece extends StatelessWidget {
  final String piece;
  final double size;
  const ChessPiece({super.key, required this.piece, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: ChessPiecePainter(piece)),
      );
}

class ChessPiecePainter extends CustomPainter {
  final String piece;
  ChessPiecePainter(this.piece);

  bool get _white => piece == piece.toUpperCase();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    canvas.save();
    canvas.scale(k);

    final path = switch (piece.toLowerCase()) {
      'p' => _pawn(),
      'r' => _rook(),
      'n' => _knight(),
      'b' => _bishop(),
      'q' => _queen(),
      _ => _king(),
    };

    // Soya
    canvas.drawOval(const Rect.fromLTWH(22, 86, 56, 9),
        Paint()..color = Colors.black.withValues(alpha: 0.35));

    final bounds = path.getBounds();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _white
            ? const [Colors.white, Color(0xFFF1EDE6), Color(0xFFC9C2B6)]
            : const [Color(0xFF6B6B6B), Color(0xFF2E2E2E), Color(0xFF0E0E0E)],
        stops: const [0, 0.5, 1],
      ).createShader(bounds);
    canvas.drawPath(path, fill);

    // Yaltiroq chiziq (yorug'lik)
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width * 0.32, bounds.height),
      Paint()..color = Colors.white.withValues(alpha: _white ? 0.35 : 0.12),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..color = _white ? const Color(0xFF2B2420) : const Color(0xFFE8E2D6).withValues(alpha: 0.55),
    );

    _details(canvas);
    canvas.restore();
  }

  void _details(Canvas canvas) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = _white ? const Color(0xFF2B2420) : const Color(0xFFE8E2D6).withValues(alpha: 0.55);
    switch (piece.toLowerCase()) {
      case 'n':
        canvas.drawCircle(const Offset(47, 31), 3.2, Paint()..color = line.color);
        canvas.drawLine(const Offset(30, 47), const Offset(36, 46), line);
      case 'b':
        canvas.drawLine(const Offset(46, 34), const Offset(56, 26), line);
      case 'k':
      case 'q':
        canvas.drawLine(const Offset(32, 60), const Offset(68, 60), line);
      default:
        break;
    }
  }

  // Umumiy asos (taglik)
  static void _base(Path p) {
    p.addRRect(RRect.fromLTRBR(20, 78, 80, 90, const Radius.circular(5)));
    p.addRRect(RRect.fromLTRBR(26, 70, 74, 80, const Radius.circular(4)));
  }

  Path _pawn() {
    final p = Path();
    _base(p);
    p.moveTo(33, 71);
    p.quadraticBezierTo(37, 56, 43, 48);
    p.lineTo(57, 48);
    p.quadraticBezierTo(63, 56, 67, 71);
    p.close();
    p.addRRect(RRect.fromLTRBR(36, 42, 64, 50, const Radius.circular(4)));
    p.addOval(Rect.fromCircle(center: const Offset(50, 30), radius: 14));
    return p;
  }

  Path _rook() {
    final p = Path();
    _base(p);
    p.moveTo(31, 71);
    p.lineTo(34, 40);
    p.lineTo(66, 40);
    p.lineTo(69, 71);
    p.close();
    p.addRRect(RRect.fromLTRBR(28, 34, 72, 42, const Radius.circular(2)));
    // Qal'a tishlari
    p.moveTo(28, 34);
    p.lineTo(28, 16);
    p.lineTo(37, 16);
    p.lineTo(37, 23);
    p.lineTo(45, 23);
    p.lineTo(45, 16);
    p.lineTo(55, 16);
    p.lineTo(55, 23);
    p.lineTo(63, 23);
    p.lineTo(63, 16);
    p.lineTo(72, 16);
    p.lineTo(72, 34);
    p.close();
    return p;
  }

  Path _knight() {
    final p = Path();
    _base(p);
    p.moveTo(70, 71);
    p.quadraticBezierTo(76, 48, 70, 32);
    p.quadraticBezierTo(66, 22, 60, 18);
    p.lineTo(58, 8); // quloq
    p.lineTo(51, 16);
    p.quadraticBezierTo(40, 16, 30, 28);
    p.quadraticBezierTo(22, 37, 21, 44); // tumshuq
    p.quadraticBezierTo(22, 51, 30, 51);
    p.quadraticBezierTo(38, 49, 44, 47); // jag'
    p.quadraticBezierTo(46, 55, 38, 62);
    p.quadraticBezierTo(33, 67, 32, 71);
    p.close();
    return p;
  }

  Path _bishop() {
    final p = Path();
    _base(p);
    p.moveTo(34, 71);
    p.quadraticBezierTo(39, 58, 43, 52);
    p.lineTo(57, 52);
    p.quadraticBezierTo(61, 58, 66, 71);
    p.close();
    p.addRRect(RRect.fromLTRBR(37, 46, 63, 53, const Radius.circular(3)));
    // Mitra
    p.moveTo(50, 12);
    p.quadraticBezierTo(66, 24, 64, 38);
    p.quadraticBezierTo(62, 46, 50, 47);
    p.quadraticBezierTo(38, 46, 36, 38);
    p.quadraticBezierTo(34, 24, 50, 12);
    p.close();
    p.addOval(Rect.fromCircle(center: const Offset(50, 9), radius: 4.5));
    return p;
  }

  Path _queen() {
    final p = Path();
    _base(p);
    p.moveTo(32, 71);
    p.quadraticBezierTo(38, 52, 34, 34);
    p.lineTo(42, 44);
    p.lineTo(46, 26);
    p.lineTo(50, 42);
    p.lineTo(54, 26);
    p.lineTo(58, 44);
    p.lineTo(66, 34);
    p.quadraticBezierTo(62, 52, 68, 71);
    p.close();
    for (final x in [34.0, 46.0, 54.0, 66.0]) {
      p.addOval(Rect.fromCircle(center: Offset(x, x == 34 || x == 66 ? 31 : 22), radius: 4.2));
    }
    p.addOval(Rect.fromCircle(center: const Offset(50, 16), radius: 4.6));
    return p;
  }

  Path _king() {
    final p = Path();
    _base(p);
    p.moveTo(32, 71);
    p.quadraticBezierTo(37, 52, 33, 36);
    p.quadraticBezierTo(50, 30, 67, 36);
    p.quadraticBezierTo(63, 52, 68, 71);
    p.close();
    p.addRRect(RRect.fromLTRBR(36, 28, 64, 37, const Radius.circular(4)));
    // Xoch
    p.addRRect(RRect.fromLTRBR(46.5, 6, 53.5, 29, const Radius.circular(1.5)));
    p.addRRect(RRect.fromLTRBR(40, 12, 60, 19, const Radius.circular(1.5)));
    return p;
  }

  @override
  bool shouldRepaint(covariant ChessPiecePainter old) => old.piece != piece;
}
