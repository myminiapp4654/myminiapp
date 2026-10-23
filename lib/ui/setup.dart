import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kit.dart';

/// O'yin sozlash oynasi: markazdan "sakrab" ochiladi.
Future<T?> showGameSetup<T>(
  BuildContext context, {
  required String title,
  required List<Color> colors,
  required Widget Function(BuildContext context, StateSetter setState) builder,
  required T Function() onStart,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Yopish',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, _, _) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: min(MediaQuery.sizeOf(ctx).width - 32, 420),
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(colors.first, const Color(0xFF14102B), 0.55)!,
                const Color(0xFF14102B),
              ],
            ),
            border: Border.all(color: colors.first.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(color: colors.first.withValues(alpha: 0.45), blurRadius: 40),
            ],
          ),
          child: StatefulBuilder(
            builder: (ctx, setState) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlowText(title, size: 26, color: Colors.white),
                  const SizedBox(height: 18),
                  builder(ctx, setState),
                  const SizedBox(height: 22),
                  GameButton(
                    key: const ValueKey('setup-start'),
                    label: 'Boshlash',
                    icon: Icons.play_arrow_rounded,
                    colors: colors,
                    onPressed: () => Navigator.pop(ctx, onStart()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) {
      final curve = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(curve), child: child),
      );
    },
  );
}

/// Bo'lim sarlavhasi.
class SetupLabel extends StatelessWidget {
  final String text;
  const SetupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      );
}

/// Tanlov kartochkasi: tanlanganda yonadi va kattalashadi.
class ChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget icon;
  final String label;
  final String? hint;
  final Color color;

  const ChoiceCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
    this.hint,
    this.color = const Color(0xFF8C7BFF),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? LinearGradient(colors: [
                    color.withValues(alpha: 0.55),
                    color.withValues(alpha: 0.2),
                  ])
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected ? color : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 16)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 44, child: Center(child: icon)),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  )),
              if (hint != null)
                Text(hint!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir qator kartochkalar (teng kenglikda).
class ChoiceRow extends StatelessWidget {
  final List<Widget> children;
  const ChoiceRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var k = 0; k < children.length; k++) ...[
            if (k > 0) const SizedBox(width: 10),
            Expanded(child: children[k]),
          ],
        ],
      );
}

/// O'yinchilar soni: har bir son tanlanganda shuncha rangli shar chiqadi.
class PlayerCountPicker extends StatelessWidget {
  final int min;
  final int max;
  final int value;
  final List<Color> colors;
  final ValueChanged<int> onChanged;

  const PlayerCountPicker({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var n = min; n <= max; n++)
              GestureDetector(
                key: ValueKey('count-$n'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(n);
                },
                child: AnimatedContainer(
                  // easeOutBack chegaradan oshib, soyani manfiy qiladi — silliq egri chiziq
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: n == value ? 52 : 42,
                  height: n == value ? 52 : 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: n == value
                        ? LinearGradient(colors: [colors.first, colors.last])
                        : null,
                    color: n == value ? null : Colors.white.withValues(alpha: 0.07),
                    border: Border.all(color: n == value ? Colors.white : Colors.white24),
                    boxShadow: n == value
                        ? [BoxShadow(color: colors.first.withValues(alpha: 0.6), blurRadius: 14)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('$n',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: n == value ? 20 : 16,
                      )),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Tanlangan son — rangli sharlar
        SizedBox(
          height: 28,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < value; k++)
                TweenAnimationBuilder<double>(
                  key: ValueKey('ball-$k-$value'),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 250 + k * 60),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GlossyBall(color: colors[k % colors.length], size: 22),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Qiyinlik arqoni: smaylikni barmoq bilan chapga (oson) yoki o'ngga (qiyin) surasiz.
/// Chapda — oddiy, bechora kulib turgan smaylik; o'ngda — shoxli binafsharang shayton.
class DifficultyRope extends StatefulWidget {
  /// 1 — oson, 2 — o'rta, 3 — qiyin.
  final int value;
  final ValueChanged<int> onChanged;

  const DifficultyRope({super.key, required this.value, required this.onChanged});

  @override
  State<DifficultyRope> createState() => _DifficultyRopeState();
}

class _DifficultyRopeState extends State<DifficultyRope> {
  /// 0..1 — smaylikning arqondagi joyi (sudrash paytida erkin, qo'yib yuborilganda
  /// eng yaqin bosqichga — 0, 0.5 yoki 1 ga — silliq "sakrab" boradi).
  late double _t = (widget.value - 1) / 2;
  bool _dragging = false;

  static const _names = ['Oson', "O'rta", 'Qiyin'];

  int get _level => (_t * 2).round() + 1;

  void _set(double t, {bool snap = false}) {
    final before = _level;
    setState(() {
      _t = snap ? ((t * 2).round() / 2).clamp(0.0, 1.0) : t.clamp(0.0, 1.0);
    });
    if (_level != before) HapticFeedback.selectionClick();
    if (snap && _level != widget.value) widget.onChanged(_level);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      const face = 64.0;
      final track = w - face;
      double toT(double dx) => ((dx - face / 2) / track).clamp(0.0, 1.0);

      return Column(
        children: [
          GestureDetector(
            key: const ValueKey('rope'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) => _set(toT(d.localPosition.dx)),
            onHorizontalDragEnd: (_) {
              setState(() => _dragging = false);
              _set(_t, snap: true);
            },
            onTapUp: (d) => _set(toT(d.localPosition.dx), snap: true),
            child: SizedBox(
              height: 96,
              // Sudrashda barmoqqa ergashadi, qo'yib yuborilganda sakrab joyiga tushadi
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _t),
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, v, _) {
                  final p = v.clamp(0.0, 1.0);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _RopePainter(p, face / 2)),
                      ),
                      Positioned(
                        left: v * track,
                        top: _dragging ? 2 : 10,
                        width: face,
                        height: face,
                        child: AnimatedScale(
                          scale: _dragging ? 1.15 : 1,
                          duration: const Duration(milliseconds: 150),
                          child: EmojiFace(p),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var k = 0; k < 3; k++)
                GestureDetector(
                  onTap: () => _set(k / 2, snap: true),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: DefaultTextStyle.of(context).style.merge(TextStyle(
                      color: _level == k + 1
                          ? [const Color(0xFFFFE082), const Color(0xFFFFB74D), const Color(0xFFD1A6FF)][k]
                          : Colors.white38,
                      fontWeight: _level == k + 1 ? FontWeight.w900 : FontWeight.w600,
                      fontSize: _level == k + 1 ? 17 : 14,
                    )),
                    child: Text(_names[k]),
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}

class _RopePainter extends CustomPainter {
  final double t;
  final double pad;
  _RopePainter(this.t, this.pad);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.45;
    final x0 = pad, x1 = size.width - pad;
    final knob = x0 + (x1 - x0) * t;
    // Arqon smaylik og'irligidan biroz egiladi
    final path = Path()
      ..moveTo(x0, y)
      ..quadraticBezierTo((x0 + knob) / 2, y + 10, knob, y + 6)
      ..quadraticBezierTo((knob + x1) / 2, y + 10, x1, y);
    final rect = Rect.fromLTRB(x0, y - 10, x1, y + 20);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = Colors.black38,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF7CF5C4), Color(0xFFFFB74D), Color(0xFFB040FF)],
        ).createShader(rect),
    );
    // Arqon o'rami naqshi
    final twist = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        final p = m.getTangentForOffset(d)!.position;
        canvas.drawLine(p + const Offset(-2, -3), p + const Offset(2, 3), twist);
      }
    }
    // Uchlaridagi qoziqlar
    for (final x in [x0, x1]) {
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = const Color(0xFF5D4037));
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF8D6E63));
    }
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) => old.t != t;
}

/// Qiyinlik yuzi: 0 — 🥱 (oson), 0.5 — 😏 (o'rta), 1 — 😈 (qiyin).
/// Oraliqda yuzlar bir-biriga silliq almashadi.
/// Rasmlar: Microsoft Fluent Emoji 3D (MIT litsenziyasi).
class EmojiFace extends StatelessWidget {
  final double t;
  const EmojiFace(this.t, {super.key});

  static const _files = ['easy', 'medium', 'hard'];

  @override
  Widget build(BuildContext context) {
    final x = t.clamp(0.0, 1.0) * 2;
    return Transform.rotate(
      // Qiyinga yaqinlashgan sari biroz qiyshayadi
      angle: (t - 0.5) * 0.25,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var k = 0; k < 3; k++)
            Opacity(
              opacity: (1 - (x - k).abs()).clamp(0.0, 1.0),
              child: Image.asset(
                'assets/images/emoji/${_files[k]}.png',
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
            ),
        ],
      ),
    );
  }
}

/// Kichik taxta rasmi (o'lcham tanlash kartochkalari uchun).
class MiniGrid extends StatelessWidget {
  final int cols;
  final int rows;
  final Color color;
  const MiniGrid({super.key, required this.cols, required this.rows, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40 * cols / max(cols, rows),
        height: 40 * rows / max(cols, rows),
        child: CustomPaint(painter: _MiniGridPainter(cols, rows, color)),
      );
}

class _MiniGridPainter extends CustomPainter {
  final int cols, rows;
  final Color color;
  _MiniGridPainter(this.cols, this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)), p);
    for (var k = 1; k < cols; k++) {
      final x = size.width * k / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p..strokeWidth = 0.6);
    }
    for (var k = 1; k < rows; k++) {
      final y = size.height * k / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p..strokeWidth = 0.6);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter old) => false;
}
