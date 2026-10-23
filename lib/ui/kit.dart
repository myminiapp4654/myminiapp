import 'dart:math';

import 'package:flutter/material.dart';

/// Oyinim dizayn to'plami: hamma o'yinlar uchun umumiy fon, panel, tugma,
/// o'yinchi belgisi va g'alaba ekrani.

class GamePalette {
  final Color top;
  final Color bottom;
  final Color accent;
  const GamePalette(this.top, this.bottom, this.accent);

  static const home = GamePalette(Color(0xFF1B1446), Color(0xFF0A0A1F), Color(0xFF8C7BFF));
  static const ludo = GamePalette(Color(0xFF3A1C71), Color(0xFF12082B), Color(0xFFFFC233));
  static const chess = GamePalette(Color(0xFF2B2118), Color(0xFF0E0B08), Color(0xFFE8C07A));
  static const sea = GamePalette(Color(0xFF0B3D6B), Color(0xFF041A33), Color(0xFF4FD1FF));
  static const checkers = GamePalette(Color(0xFF3B1E10), Color(0xFF140A05), Color(0xFFFF8A3D));
  static const xo = GamePalette(Color(0xFF15204A), Color(0xFF070B1E), Color(0xFF5CE1E6));
  static const chain = GamePalette(Color(0xFF1A0B2E), Color(0xFF07020F), Color(0xFFFF4D8D));
  static const orbs = GamePalette(Color(0xFF102A43), Color(0xFF050D18), Color(0xFF7CF5C4));
  static const walls = GamePalette(Color(0xFF3A1F14), Color(0xFF120804), Color(0xFFFFB347));
}

/// Gradientli fon, ustida sekin suzuvchi nurlar.
class GameBackground extends StatefulWidget {
  final GamePalette palette;
  final Widget child;
  const GameBackground({super.key, required this.palette, required this.child});

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.bottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _GlowPainter(_c.value, p.accent),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final double t;
  final Color color;
  _GlowPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 0; k < 3; k++) {
      final a = (t + k / 3) * 2 * pi;
      final center = Offset(
        size.width * (0.5 + 0.38 * cos(a + k)),
        size.height * (0.4 + 0.3 * sin(a * 0.7 + k * 2)),
      );
      final r = size.shortestSide * (0.45 + 0.1 * k);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: 0.16 - k * 0.04),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.t != t;
}

/// O'yin ekrani: shaffof AppBar + gradient fon.
class GameScaffold extends StatelessWidget {
  final String title;
  final GamePalette palette;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;

  const GameScaffold({
    super.key,
    required this.title,
    required this.palette,
    required this.body,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: palette.bottom,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: leading,
        actions: actions,
      ),
      body: GameBackground(
        palette: palette,
        child: SafeArea(child: body),
      ),
    );
  }
}

/// Shishasimon panel.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;

  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 18,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tint ?? Colors.white).withValues(alpha: 0.14),
            (tint ?? Colors.white).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

/// Gradientli tugma, bosganda kichrayadi.
class GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color> colors;
  final bool outlined;
  final bool expand;

  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = const [Color(0xFFFFB347), Color(0xFFFF6A3D)],
    this.outlined = false,
    this.expand = true,
  });

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colors = enabled ? widget.colors : [Colors.grey.shade700, Colors.grey.shade800];
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: widget.outlined
                ? null
                : LinearGradient(colors: colors),
            color: widget.outlined ? Colors.white.withValues(alpha: 0.06) : null,
            border: widget.outlined
                ? Border.all(color: colors.first.withValues(alpha: 0.8), width: 2)
                : null,
            boxShadow: widget.outlined || !enabled
                ? null
                : [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: content,
        ),
      ),
    );
  }
}

/// O'yinchi belgisi: navbati kelganda yonadi.
class PlayerBadge extends StatelessWidget {
  final Color color;
  final String name;
  final String? value;
  final bool active;
  final bool dimmed;
  final Widget? avatar;

  const PlayerBadge({
    super.key,
    required this.color,
    required this.name,
    this.value,
    this.active = false,
    this.dimmed = false,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: active ? color.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: active ? color : Colors.white.withValues(alpha: 0.12),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16)]
            : null,
      ),
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar ??
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.3),
                      colors: [Color.lerp(color, Colors.white, 0.5)!, color],
                    ),
                  ),
                ),
            const SizedBox(width: 8),
            Text(name,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  decoration: dimmed ? TextDecoration.lineThrough : null,
                )),
            if (value != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(value!,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Katta, yaltiroq sarlavha matni.
class GlowText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const GlowText(this.text, {super.key, this.size = 22, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.7), blurRadius: 14),
          const Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

/// G'alaba ekrani: konfetti + sarlavha + tugmalar.
class WinOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Color color;
  final bool confetti;

  const WinOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.color = const Color(0xFFFFC233),
    this.confetti = true,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
        ..forward();
  final _pieces = List.generate(90, (i) => _Confetti(Random(i)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _c, curve: const Interval(0, 0.15)),
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        if (widget.confetti)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) =>
                    CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
              ),
            ),
          ),
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(
                parent: _c, curve: const Interval(0, 0.25, curve: Curves.elasticOut)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Glass(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                radius: 28,
                tint: widget.color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlowText(widget.title, size: 28, color: widget.color),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ],
                    const SizedBox(height: 20),
                    for (final a in widget.actions)
                      Padding(padding: const EdgeInsets.only(top: 8), child: a),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Confetti {
  final double x, speed, drift, spin, size;
  final Color color;
  _Confetti(Random r)
      : x = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        drift = (r.nextDouble() - 0.5) * 0.3,
        spin = r.nextDouble() * 10,
        size = 6 + r.nextDouble() * 6,
        color = const [
          Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE),
          Color(0xFF40C4FF), Color(0xFFB388FF), Color(0xFFFF80AB),
        ][r.nextInt(6)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = (-0.1 + t * p.speed * 1.4) * size.height;
      if (y > size.height) continue;
      final x = (p.x + p.drift * t + sin(t * 8 + p.spin) * 0.02) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * p.spin * 3);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
        Paint()..color = p.color.withValues(alpha: (1.2 - t).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Hajmli shar/dona: yorug'lik yuqori chapdan tushadi.
class GlossyBall extends StatelessWidget {
  final Color color;
  final double size;
  final Widget? child;
  final bool glow;

  const GlossyBall({
    super.key,
    required this.color,
    required this.size,
    this.child,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [
            Color.lerp(color, Colors.white, 0.65)!,
            color,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.45, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: glow ? color.withValues(alpha: 0.8) : Colors.black54,
            blurRadius: glow ? 14 : 4,
            spreadRadius: glow ? 2 : 0,
            offset: glow ? Offset.zero : Offset(0, size * 0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
