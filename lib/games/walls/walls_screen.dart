import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../telegram/telegram.dart';
import 'walls_game.dart';

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

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escape the Walls'),
        actions: [
          IconButton(
            key: const ValueKey('shop'),
            icon: const Icon(Icons.storefront),
            tooltip: "Do'kon",
            onPressed: _openShop,
          ),
        ],
      ),
      body: SafeArea(
        child: g.escaped ? _buildEscaped(g) : Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('💰 ${formatMoney(g.money)}', style: text.titleLarge),
                  const Spacer(),
                  Text('${g.wall}/${WallsGame.finalWall}-devor',
                      style: text.titleMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${WallsGame.tools[g.tool].name} • zarba ${formatMoney(g.tapDamage)}'),
                  const Spacer(),
                  if (g.dps > 0) Text('👷 ${formatMoney(g.dps)}/s'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              child: Text(_event ?? "G'ishtni bosing!", style: text.bodyMedium),
            ),
            Expanded(child: _buildWall(g)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text("G'isht: ${g.bricksLeft}/${g.bricks.length}"
                        '${g.escapes > 0 ? '  •  daromad ×${g.incomeMultiplier.toStringAsFixed(2)}' : ''}'),
                  ),
                  FilledButton.tonal(
                    onPressed: g.dynamite > 0
                        ? () => setState(() => _dynamiteMode = !_dynamiteMode)
                        : null,
                    style: _dynamiteMode
                        ? FilledButton.styleFrom(backgroundColor: Colors.deepOrange)
                        : null,
                    child: Text('🧨 ${g.dynamite}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _brickColor(WallsGame g, int i) {
    final b = g.bricks[i];
    final revealed = g.isRevealed(i);
    return switch (b.type) {
      BrickType.stone => const Color(0xFF8D8D8D),
      BrickType.metal => const Color(0xFF6E8CA0),
      BrickType.treasure when revealed => const Color(0xFFE0B03A),
      BrickType.shock when revealed => const Color(0xFF7B5CD6),
      BrickType.collapse when revealed => const Color(0xFF5D4037),
      _ => const Color(0xFFB5523B),
    };
  }

  String _brickIcon(WallsGame g, int i) {
    if (!g.isRevealed(i)) return '';
    return switch (g.bricks[i].type) {
      BrickType.treasure => '💰',
      BrickType.shock => '⚡',
      BrickType.collapse => '⚠',
      _ => '',
    };
  }

  Widget _buildWall(WallsGame g) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(
        child: AspectRatio(
          aspectRatio: WallsGame.cols / WallsGame.rows,
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
                // Uchib chiqadigan yozuvlar
                for (final f in _floaters)
                  Positioned(
                    key: f.key,
                    left: (f.cell % WallsGame.cols) * cw,
                    top: (f.cell ~/ WallsGame.cols) * ch - 10,
                    width: cw,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        builder: (_, t, child) => Opacity(
                          opacity: 1 - t,
                          child: Transform.translate(
                              offset: Offset(0, -24 * t), child: child),
                        ),
                        child: Text(f.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: f.color,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(blurRadius: 3, color: Colors.black)
                                ])),
                      ),
                    ),
                  ),
                if (g.stunned > 0)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text('⚡ ${g.stunned.toStringAsFixed(1)} s',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBrick(WallsGame g, int i) {
    final b = g.bricks[i];
    if (b.broken) {
      return const Padding(
        padding: EdgeInsets.all(1.5),
        child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF1B1B1B))),
      );
    }
    final health = (b.hp / b.maxHp).clamp(0.0, 1.0);
    final color = _brickColor(g, i);
    return GestureDetector(
      key: ValueKey('brick-$i'),
      onTapDown: (_) => _tap(i),
      child: AnimatedScale(
        scale: _pressed == i ? 0.88 : 1,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: Container(
            decoration: BoxDecoration(
              // Shikastlangan sari xiralashadi
              color: Color.lerp(const Color(0xFF2A2A2A), color, 0.35 + 0.65 * health),
              borderRadius: BorderRadius.circular(2),
              border: _dynamiteMode
                  ? Border.all(color: Colors.deepOrange, width: 1.5)
                  : null,
            ),
            child: Stack(
              children: [
                Center(child: Text(_brickIcon(g, i))),
                if (health < 1)
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 2,
                    child: LinearProgressIndicator(
                      value: health,
                      minHeight: 3,
                      color: Colors.white70,
                      backgroundColor: Colors.black26,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscaped(WallsGame g) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: text.displayMedium),
            Text('Qochib chiqdingiz!', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('${WallsGame.finalWall} ta devorni buzdingiz. '
                "Qaytadan boshlasangiz, daromad ×${(g.incomeMultiplier + 0.25).toStringAsFixed(2)} bo'ladi.",
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  g.restartAfterEscape();
                  _event = null;
                });
                _save();
              },
              child: const Text('Qaytadan boshlash'),
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

        Widget item(String title, String subtitle, double? cost,
            bool Function() action,
            {bool done = false}) {
          final can = !done && cost != null && g.money >= cost;
          return ListTile(
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: done
                ? const Icon(Icons.check)
                : FilledButton(
                    onPressed: can ? () => buy(action) : null,
                    child: Text('💰 ${formatMoney(cost ?? 0)}'),
                  ),
          );
        }

        final nextTool = g.tool + 1 < WallsGame.tools.length
            ? WallsGame.tools[g.tool + 1]
            : null;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            children: [
              ListTile(
                title: Text("Do'kon", style: Theme.of(ctx).textTheme.titleLarge),
                trailing: Text('💰 ${formatMoney(g.money)}',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              const Divider(),
              if (nextTool != null)
                item('🔨 ${nextTool.name}',
                    'Asbob: zarba ×${nextTool.power.toStringAsFixed(0)}',
                    nextTool.price, g.buyTool)
              else
                item('🔨 ${WallsGame.tools.last.name}', 'Eng zo\'r asbob', null,
                    () => false, done: true),
              item('💪 Kuch (${g.powerLvl}-daraja)',
                  'Zarba +${formatMoney(g.toolPower)}', g.powerCost, g.buyPower),
              item('🎯 Kritik zarba (${g.critLvl}/10)',
                  '${(g.critChance * 100).toStringAsFixed(0)}% ehtimol, ×3 zarba',
                  g.critCost, g.buyCrit,
                  done: g.critMaxed),
              item('👷 Ishchi (${g.workerLvl} ta)',
                  'Devorni o\'zi buzadi: +${formatMoney(0.6 * g.toolPower)}/s',
                  g.workerCost, g.buyWorker),
              item('🍀 Omad (${g.luckLvl}/10)',
                  'Topilma va xazina ko\'proq chiqadi', g.luckCost, g.buyLuck,
                  done: g.luckMaxed),
              item('📡 Skaner', 'Tuzoq va xazinalarni ko\'rsatadi',
                  WallsGame.scannerCost, g.buyScanner,
                  done: g.scanner),
              item('🧤 Rezina qo\'lqop', 'Tok urmaydi', WallsGame.insulationCost,
                  g.buyInsulation,
                  done: g.insulation),
              item('🧨 Dinamit (${g.dynamite} ta)',
                  '3×3 maydonni portlatadi, tuzoqlar ishlamaydi',
                  g.dynamiteCost, g.buyDynamite),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }
}
