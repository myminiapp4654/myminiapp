import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telegram/telegram.dart';
import 'walls_game.dart';
import '../../ui/kit.dart';

/// Katta sonlarni qisqa ko'rsatish: 1250 -> 1.3K
String formatMoney(double v) {
  if (v < 1000) return v.toStringAsFixed(v < 10 ? 1 : 0);
  const units = ['K', 'M', 'B', 'T'];
  var x = v;
  var u = -1;
  while (x >= 1000 && u < units.length - 1) {
    x /= 1000;
    u++;
  }
  return '${x.toStringAsFixed(x < 10 ? 1 : 0)}${units[u]}';
}

/// G'isht ustida uchib chiqadigan yozuv (+12, KRIT!, ⚡).
class _Floater {
  final int cell;
  final String text;
  final Color color;
  final Key key = UniqueKey();
  _Floater(this.cell, this.text, this.color);
}

class WallsScreen extends StatefulWidget {
  const WallsScreen({super.key});

  @override
  State<WallsScreen> createState() => _WallsScreenState();
}

class _WallsScreenState extends State<WallsScreen> {
  static const _saveKey = 'walls_save_v1';

  WallsGame? _game;
  Timer? _timer;
  bool _dirty = false;
  double _sinceSave = 0;

  bool _dynamiteMode = false;
  String? _event;
  int? _pressed;
  final _floaters = <_Floater>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _save();
    super.dispose();
  }

  // ---------------------------------------------------------------- saqlash

  Future<void> _load() async {
    WallsGame game;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      game = raw == null
          ? WallsGame()
          : WallsGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      game = WallsGame();
    }
    if (!mounted) return;
    setState(() => _game = game);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  Future<void> _save() async {
    final g = _game;
    if (g == null) return;
    _dirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(g.toJson()));
    } catch (_) {}
  }

  // ---------------------------------------------------------------- o'yin

  void _tick() {
    final g = _game!;
    final wasStunned = g.stunned > 0;
    final results = g.tick(0.1);
    for (final r in results) {
      _onResult(r, null);
    }
    _sinceSave += 0.1;
    if (_dirty && _sinceSave >= 3) {
      _sinceSave = 0;
      _save();
    }
    if (results.isNotEmpty || wasStunned) setState(() {});
  }

  void _tap(int i) {
    final g = _game!;
    if (_dynamiteMode) {
      final results = g.useDynamite(i);
      if (results.isEmpty) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _dynamiteMode = false;
        _event = '🧨 Bum! +${formatMoney(results.fold(0.0, (s, r) => s + r.gained))}';
        for (final r in results) {
          _onResult(r, null);
        }
      });
      _dirty = true;
      return;
    }
    final r = g.tap(i);
    if (r.damage == 0) return;
    Telegram.haptic();
    HapticFeedback.selectionClick();
    setState(() {
      _pressed = i;
      _onResult(r, i);
    });
    _dirty = true;
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted && _pressed == i) setState(() => _pressed = null);
    });
  }

  /// Natijani ekranda ko'rsatish (yozuvlar va voqealar).
  void _onResult(HitResult r, int? cell) {
    if (cell != null && r.crit) {
      _float(cell, 'KRIT!', Colors.orangeAccent);
    }
    if (!r.broken) return;
    _dirty = true;
    if (cell != null) _float(cell, '+${formatMoney(r.gained)}', Colors.amber);
    if (r.loot != null) {
      _event = '${r.loot == 'Olmos' ? '💎' : '🪙'} ${r.loot} topildi! +${formatMoney(r.gained)}';
    }
    if (r.trap == BrickType.shock) {
      _event = _game!.insulation
          ? '⚡ Tok — himoya ishladi'
          : '⚡ Tok urdi! Qo\'l biroz ishlamaydi';
      HapticFeedback.vibrate();
    }
    if (r.trap == BrickType.collapse) {
      _event = "🧱 Qulash! G'ishtlar qayta tushdi";
    }
    if (r.wallCleared) {
      _event = _game!.escaped
          ? '🎉 Qochib chiqdingiz!'
          : '🧱 Devor buzildi! ${_game!.wall}-devor';
      _save();
    }
  }

  void _float(int cell, String text, Color color) {
    final f = _Floater(cell, text, color);
    _floaters.add(f);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _floaters.remove(f));
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) {
      return const Scaffold(
          backgroundColor: Color(0xFF120804),
          body: Center(child: CircularProgressIndicator()));
    }

    return GameScaffold(
      title: 'Escape the Walls',
      palette: GamePalette.walls,
      actions: [
        IconButton(
          key: const ValueKey('shop'),
          icon: const Icon(Icons.storefront_rounded),
          tooltip: "Do'kon",
          onPressed: _openShop,
        ),
      ],
      body: g.escaped ? _buildEscaped(g) : Column(
        children: [
          _buildHud(g),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_event),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(_event ?? "G'ishtni bosing!",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildWall(g)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    g.escapes > 0
                        ? 'Daromad ×${g.incomeMultiplier.toStringAsFixed(2)}'
                        : 'Tuzoqlardan ehtiyot bo\'ling!',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                GameButton(
                  label: _dynamiteMode ? 'Joyni tanlang' : 'Dinamit ×${g.dynamite}',
                  icon: Icons.local_fire_department_rounded,
                  expand: false,
                  colors: _dynamiteMode
                      ? const [Color(0xFFFF5252), Color(0xFFB71C1C)]
                      : const [Color(0xFFFFB347), Color(0xFFFF6A3D)],
                  onPressed: g.dynamite > 0
                      ? () => setState(() => _dynamiteMode = !_dynamiteMode)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHud(WallsGame g) {
    final cleared = 1 - g.bricksLeft / g.bricks.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Glass(
        tint: const Color(0xFFFFB347),
        child: Column(
          children: [
            Row(
              children: [
                const _Coin(size: 26),
                const SizedBox(width: 8),
                Text(formatMoney(g.money),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${g.wall}/${WallsGame.finalWall}-devor',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    Text("G'isht: ${g.bricksLeft}/${g.bricks.length}",
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 8, color: Colors.white12),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 250),
                    widthFactor: cleared.clamp(0.0, 1.0),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFF8F00)]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(Icons.handyman_rounded,
                    '${WallsGame.tools[g.tool].name} • ${formatMoney(g.tapDamage)}'),
                const SizedBox(width: 6),
                if (g.dps > 0) _chip(Icons.engineering_rounded, '${formatMoney(g.dps)}/s'),
                const Spacer(),
                if (g.scanner) const Icon(Icons.radar_rounded, color: Color(0xFF7CF5C4), size: 18),
                if (g.insulation)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.bolt_rounded, color: Color(0xFFB388FF), size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFFFFCC80)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      );

  Widget _buildWall(WallsGame g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: AspectRatio(
          aspectRatio: WallsGame.cols / WallsGame.rows,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A22),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10)),
              ],
            ),
            child: LayoutBuilder(builder: (context, box) {
              final cw = box.maxWidth / WallsGame.cols;
              final ch = box.maxHeight / WallsGame.rows;
              return Stack(
                children: [
                  for (var i = 0; i < g.bricks.length; i++)
                    Positioned(
                      left: (i % WallsGame.cols) * cw,
                      top: (i ~/ WallsGame.cols) * ch,
                      width: cw,
                      height: ch,
                      child: _buildBrick(g, i),
                    ),
                  for (final f in _floaters)
                    Positioned(
                      key: f.key,
                      left: (f.cell % WallsGame.cols) * cw - cw * 0.25,
                      top: (f.cell ~/ WallsGame.cols) * ch - 10,
                      width: cw * 1.5,
                      child: IgnorePointer(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          builder: (_, t, child) => Opacity(
                            opacity: 1 - t,
                            child: Transform.translate(
                                offset: Offset(0, -28 * t),
                                child: Transform.scale(scale: 1 + 0.3 * (1 - t), child: child)),
                          ),
                          child: Text(f.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: f.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  shadows: const [Shadow(blurRadius: 4, color: Colors.black)])),
                        ),
                      ),
                    ),
                  if (g.stunned > 0)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF311B92).withValues(alpha: 0.6),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFFFEB3B), size: 64),
                            GlowText('${g.stunned.toStringAsFixed(1)} s',
                                size: 28, color: const Color(0xFFE1BEE7)),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildBrick(WallsGame g, int i) {
    final b = g.bricks[i];
    if (b.broken) {
      return CustomPaint(painter: _HolePainter());
    }
    final health = (b.hp / b.maxHp).clamp(0.0, 1.0);
    return GestureDetector(
      key: ValueKey('brick-$i'),
      onTapDown: (_) => _tap(i),
      child: AnimatedScale(
        scale: _pressed == i ? 0.86 : 1,
        duration: const Duration(milliseconds: 80),
        child: CustomPaint(
          painter: _BrickPainter(
            type: b.type,
            health: health,
            revealed: g.isRevealed(i),
            seed: i,
            dynamite: _dynamiteMode,
          ),
        ),
      ),
    );
  }

  Widget _buildEscaped(WallsGame g) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0xFFFFF8E1), Color(0x00FFB347)]),
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 80, color: Color(0xFFFFC107)),
            ),
            const GlowText('Qochib chiqdingiz!', size: 30, color: Color(0xFFFFD54F)),
            const SizedBox(height: 8),
            Text(
              '${WallsGame.finalWall} ta devorni buzdingiz. '
              "Qaytadan boshlasangiz, daromad ×${(g.incomeMultiplier + 0.25).toStringAsFixed(2)} bo'ladi.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            GameButton(
              label: 'Qaytadan boshlash',
              icon: Icons.replay_rounded,
              expand: false,
              onPressed: () {
                setState(() {
                  g.restartAfterEscape();
                  _event = null;
                });
                _save();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- do'kon

  void _openShop() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) {
        final g = _game!;
        void buy(bool Function() action) {
          if (action()) {
            HapticFeedback.mediumImpact();
            _dirty = true;
            refresh(() {});
            setState(() {});
          }
        }

        Widget item(String icon, String title, String subtitle, double? cost,
            bool Function() action,
            {bool done = false}) {
          final can = !done && cost != null && g.money >= cost;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Glass(
              tint: const Color(0xFFFFB347),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(subtitle,
                            style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (done)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF7CF5C4))
                  else
                    GameButton(
                      label: formatMoney(cost ?? 0),
                      expand: false,
                      icon: Icons.monetization_on_rounded,
                      onPressed: can ? () => buy(action) : null,
                    ),
                ],
              ),
            ),
          );
        }

        final nextTool = g.tool + 1 < WallsGame.tools.length
            ? WallsGame.tools[g.tool + 1]
            : null;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Row(
                  children: [
                    const Text("Do'kon",
                        style: TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    const _Coin(size: 22),
                    const SizedBox(width: 6),
                    Text(formatMoney(g.money),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (nextTool != null)
                item('🔨', nextTool.name, 'Asbob: zarba ×${nextTool.power.toStringAsFixed(0)}',
                    nextTool.price, g.buyTool)
              else
                item('🔨', WallsGame.tools.last.name, "Eng zo'r asbob", null, () => false,
                    done: true),
              item('💪', 'Kuch (${g.powerLvl}-daraja)', 'Zarba +${formatMoney(g.toolPower)}',
                  g.powerCost, g.buyPower),
              item('🎯', 'Kritik zarba (${g.critLvl}/10)',
                  '${(g.critChance * 100).toStringAsFixed(0)}% ehtimol, ×3 zarba', g.critCost,
                  g.buyCrit,
                  done: g.critMaxed),
              item('👷', 'Ishchi (${g.workerLvl} ta)',
                  "Devorni o'zi buzadi: +${formatMoney(0.6 * g.toolPower)}/s", g.workerCost,
                  g.buyWorker),
              item('🍀', 'Omad (${g.luckLvl}/10)', "Topilma va xazina ko'proq chiqadi",
                  g.luckCost, g.buyLuck,
                  done: g.luckMaxed),
              item('📡', 'Skaner', "Tuzoq va xazinalarni ko'rsatadi", WallsGame.scannerCost,
                  g.buyScanner,
                  done: g.scanner),
              item('🧤', "Rezina qo'lqop", 'Tok urmaydi', WallsGame.insulationCost,
                  g.buyInsulation,
                  done: g.insulation),
              item('🧨', 'Dinamit (${g.dynamite} ta)',
                  '3×3 maydonni portlatadi, tuzoqlar ishlamaydi', g.dynamiteCost,
                  g.buyDynamite),
            ],
          ),
        );
      }),
    );
  }
}

/// Oltin tanga.
class _Coin extends StatelessWidget {
  final double size;
  const _Coin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFFF59D), Color(0xFFFFC107), Color(0xFFB8860B)],
        ),
        border: Border.all(color: const Color(0xFF8D6E00), width: size * 0.06),
      ),
      alignment: Alignment.center,
      child: Text('\$',
          style: TextStyle(
              color: const Color(0xFF8D6E00), fontWeight: FontWeight.w900, fontSize: size * 0.55)),
    );
  }
}

/// Buzilgan joy: chuqurlik va tashqaridan tushayotgan yorug'lik.
class _HolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFE0B2).withValues(alpha: 0.35),
          const Color(0xFF1A0E08),
        ]).createShader(r),
    );
    // Ichki soya (chuqurlik)
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// G'isht: turi, yoriqlar (shikastlanish), maxsus belgilar.
class _BrickPainter extends CustomPainter {
  final BrickType type;
  final double health;
  final bool revealed;
  final int seed;
  final bool dynamite;

  _BrickPainter({
    required this.type,
    required this.health,
    required this.revealed,
    required this.seed,
    required this.dynamite,
  });

  List<Color> get _colors => switch (type) {
        BrickType.stone => const [Color(0xFFA7A7A7), Color(0xFF6E6E6E)],
        BrickType.metal => const [Color(0xFF9FB4C4), Color(0xFF4F6576)],
        BrickType.treasure when revealed => const [Color(0xFFFFE082), Color(0xFFC79100)],
        BrickType.shock when revealed => const [Color(0xFF9575CD), Color(0xFF4527A0)],
        BrickType.collapse when revealed => const [Color(0xFF8D6E63), Color(0xFF4E342E)],
        _ => const [Color(0xFFD2694A), Color(0xFF8E3B26)],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(1.5);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
    final colors = _colors;
    final dim = 0.35 + 0.65 * health;

    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A1A12), colors[0], dim)!,
            Color.lerp(const Color(0xFF2A1A12), colors[1], dim)!,
          ],
        ).createShader(r),
    );
    // Yuqori yorug'lik, pastki soya
    canvas.drawLine(r.topLeft + const Offset(3, 1.5), r.topRight + const Offset(-3, 1.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 2);
    canvas.drawLine(r.bottomLeft + const Offset(3, -1.5), r.bottomRight + const Offset(-3, -1.5),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..strokeWidth = 2);

    final rnd = Random(seed * 31 + 7);
    // Tekstura
    if (type == BrickType.stone || type == BrickType.normal) {
      for (var k = 0; k < 7; k++) {
        canvas.drawCircle(
          Offset(r.left + rnd.nextDouble() * r.width, r.top + rnd.nextDouble() * r.height),
          0.8 + rnd.nextDouble() * 1.4,
          Paint()..color = Colors.black.withValues(alpha: 0.12),
        );
      }
    }
    if (type == BrickType.metal) {
      final rivet = Paint()..color = const Color(0xFFDCE6EE);
      for (final p in [
        r.topLeft + const Offset(5, 5),
        r.topRight + const Offset(-5, 5),
        r.bottomLeft + const Offset(5, -5),
        r.bottomRight + const Offset(-5, -5),
      ]) {
        canvas.drawCircle(p, 2, rivet);
      }
    }
    if (revealed) {
      final c = r.center;
      final s = r.shortestSide;
      switch (type) {
        case BrickType.treasure:
          canvas.drawCircle(c, s * 0.22, Paint()..color = const Color(0xFFFFF8E1).withValues(alpha: 0.9));
          canvas.drawCircle(c, s * 0.14, Paint()..color = const Color(0xFFFFB300));
        case BrickType.shock:
          final bolt = Path()
            ..moveTo(c.dx + s * 0.05, c.dy - s * 0.32)
            ..lineTo(c.dx - s * 0.15, c.dy + s * 0.04)
            ..lineTo(c.dx + s * 0.02, c.dy + s * 0.04)
            ..lineTo(c.dx - s * 0.06, c.dy + s * 0.32)
            ..lineTo(c.dx + s * 0.16, c.dy - s * 0.06)
            ..lineTo(c.dx - s * 0.01, c.dy - s * 0.06)
            ..close();
          canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFEB3B));
        case BrickType.collapse:
          final tri = Path()
            ..moveTo(c.dx, c.dy - s * 0.26)
            ..lineTo(c.dx + s * 0.26, c.dy + s * 0.2)
            ..lineTo(c.dx - s * 0.26, c.dy + s * 0.2)
            ..close();
          canvas.drawPath(tri, Paint()..color = const Color(0xFFFFC107));
        default:
          break;
      }
    }

    // Yoriqlar: shikastlangan sari ko'payadi
    final cracks = ((1 - health) * 6).round();
    final crack = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < cracks; k++) {
      final path = Path();
      var p = Offset(r.left + rnd.nextDouble() * r.width, r.top + rnd.nextDouble() * r.height);
      path.moveTo(p.dx, p.dy);
      for (var j = 0; j < 3; j++) {
        p += Offset((rnd.nextDouble() - 0.5) * r.width * 0.5, (rnd.nextDouble() - 0.5) * r.height * 0.6);
        path.lineTo(p.dx.clamp(r.left, r.right), p.dy.clamp(r.top, r.bottom));
      }
      canvas.drawPath(path, crack);
    }

    if (dynamite) {
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFF5252));
    }
  }

  @override
  bool shouldRepaint(covariant _BrickPainter old) =>
      old.health != health || old.type != type || old.revealed != revealed || old.dynamite != dynamite;
}
