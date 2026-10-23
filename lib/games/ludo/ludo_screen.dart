import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import '../../ui/setup.dart';
import 'ludo_game.dart';

const kLudoColors = [
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF1E88E5),
];
const kLudoNames = ['Qizil', 'Yashil', 'Sariq', "Ko'k"];

/// Sozlamalar: nechta o'yinchi va kim kompyuter.
Future<({int players, Set<int> ai})?> showLudoSetup(BuildContext context) {
  var players = 2;
  final ai = <int>{2}; // 2 kishida sariq — kompyuter
  return showGameSetup(
    context,
    title: 'Ludo',
    colors: const [Color(0xFFFFC233), Color(0xFFF107A3)],
    onStart: () {
      final colors = LudoGame.colorsFor(players);
      return (players: players, ai: ai.where(colors.contains).toSet());
    },
    builder: (ctx, setState) {
      final colors = LudoGame.colorsFor(players);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SetupLabel("O'yinchilar soni"),
          PlayerCountPicker(
            min: 2,
            max: 4,
            value: players,
            colors: [for (final c in colors) kLudoColors[c]],
            onChanged: (n) => setState(() => players = n),
          ),
          const SetupLabel("Kim o'ynaydi — bosib almashtiring"),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final c in colors)
                GestureDetector(
                  key: ValueKey('seat-$c'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => ai.contains(c) ? ai.remove(c) : ai.add(c));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 82,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(colors: [
                        kLudoColors[c].withValues(alpha: 0.6),
                        kLudoColors[c].withValues(alpha: 0.2),
                      ]),
                      border: Border.all(color: kLudoColors[c], width: 2),
                    ),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, a) => RotationTransition(
                            turns: Tween(begin: 0.5, end: 1.0).animate(a),
                            child: ScaleTransition(scale: a, child: child),
                          ),
                          child: Icon(
                            ai.contains(c) ? Icons.smart_toy_rounded : Icons.person_rounded,
                            key: ValueKey(ai.contains(c)),
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(kLudoNames[c],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(ai.contains(c) ? 'Kompyuter' : 'Odam',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

class LudoScreen extends StatefulWidget {
  final int players;
  final Set<int> ai;

  /// Tayyor o'yin holati (test va ekran rasmlari uchun).
  final LudoGame? initialGame;

  const LudoScreen(
      {super.key, this.players = 2, this.ai = const {}, this.initialGame});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with TickerProviderStateMixin {
  late LudoGame _game = widget.initialGame ?? _newGame();

  /// Animatsiya paytida donalarning ko'rinadigan holati.
  List<List<int>>? _display;
  bool _busy = false;
  bool _rolling = false;
  int _face = 1;
  String _status = '';
  Timer? _aiTimer;

  /// Yura oladigan donalar sakrab turadi.
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  /// Hozir yurayotgan dona (sakrash effekti uchun).
  (int, int)? _hopping;

  /// Urish joyidagi portlash effektlari.
  final _bursts = <(Key, (double, double), Color)>[];

  /// Tosh aylanishi (burchak).
  double _diceTurns = 0;

  LudoGame _newGame() =>
      LudoGame(colors: LudoGame.colorsFor(widget.players), ai: widget.ai);

  @override
  void initState() {
    super.initState();
    _status = _turnText();
    _scheduleAi();
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _turnText() {
    final g = _game;
    if (g.phase == LudoPhase.finished) return '${kLudoNames[g.winner!]} yutdi!';
    final who = kLudoNames[g.current];
    if (g.isAiTurn) return "$who (kompyuter) o'ylayapti...";
    return g.phase == LudoPhase.roll
        ? '$who navbati — toshni tashlang'
        : '$who: donani tanlang';
  }

  // ---------------------------------------------------------------- tosh

  Future<void> _roll() async {
    final g = _game;
    if (_busy || _rolling || g.phase != LudoPhase.roll) return;
    final player = g.current;
    setState(() => _rolling = true);
    Telegram.haptic();
    final rnd = Random();
    for (var k = 0; k < 7; k++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() {
        _face = rnd.nextInt(6) + 1;
        _diceTurns += 0.23;
      });
    }
    final v = g.roll();
    setState(() {
      _rolling = false;
      _face = v;
      _diceTurns = _diceTurns.roundToDouble();
    });

    if (g.current != player) {
      // Yurish yo'q yoki uchinchi 6
      // 6 tushib navbat o'tdi — demak bu ketma-ket uchinchi 6
      final why = v == 6 ? 'Uchta 6 — navbat yondi' : "$v — yurish yo'q";
      setState(() => _status = why);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _status = _turnText());
      _scheduleAi();
      return;
    }
    if (g.phase == LudoPhase.roll) {
      // 6 tushdi, lekin yurish yo'q — yana tashlaydi
      setState(() => _status = '6! Yana tashlang');
      _scheduleAi();
      return;
    }
    final legal = g.legalTokens();
    if (legal.length == 1 && !g.isAiTurn) {
      await Future.delayed(const Duration(milliseconds: 250));
      await _move(legal.single);
      return;
    }
    setState(() => _status = _turnText());
    _scheduleAi();
  }

  // ---------------------------------------------------------------- yurish

  Future<void> _move(int t) async {
    final g = _game;
    if (_busy || g.phase != LudoPhase.move || !g.legalTokens().contains(t)) {
      return;
    }
    final color = g.current;
    final snapshot = [for (final row in g.tokens) List.of(row)];
    final m = g.move(t);
    if (m == null) return;

    // Dona katakma-katak yuradi; urilganlar oxirida uychaga qaytadi
    setState(() {
      _busy = true;
      _display = snapshot;
      _hopping = (color, t);
    });
    if (m.from == -1) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _display![color][t] = 0);
      HapticFeedback.selectionClick();
    } else {
      for (var p = m.from + 1; p <= m.to; p++) {
        await Future.delayed(const Duration(milliseconds: 130));
        if (!mounted) return;
        setState(() => _display![color][t] = p);
        HapticFeedback.selectionClick();
      }
    }
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    String? note;
    if (m.captured.isNotEmpty) {
      HapticFeedback.heavyImpact();
      final at = ludoCell(color, t, m.to);
      final b = (UniqueKey() as Key, at, kLudoColors[color]);
      _bursts.add(b);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _bursts.remove(b));
      });
      note = '${kLudoNames[color]} ${m.captured.map((c) => kLudoNames[c.$1]).toSet().join(', ')}ni urdi!';
    } else if (m.reachedHome) {
      note = '${kLudoNames[color]} donasi marraga yetdi!';
    }
    setState(() {
      _display = null;
      _busy = false;
      _hopping = null;
      _status = note == null ? _turnText() : '$note  ${_turnText()}';
    });
    _scheduleAi();
  }

  void _scheduleAi() {
    _aiTimer?.cancel();
    final g = _game;
    if (!g.isAiTurn || g.phase == LudoPhase.finished) return;
    _aiTimer = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted || _busy || _rolling) return;
      if (g.phase == LudoPhase.roll) {
        await _roll();
      } else if (g.phase == LudoPhase.move) {
        final t = g.aiChoose();
        if (t != null) await _move(t);
      }
    });
  }

  void _restart() {
    _aiTimer?.cancel();
    setState(() {
      _game = _newGame();
      _display = null;
      _busy = false;
      _status = _turnText();
    });
    _scheduleAi();
  }


  // ---------------------------------------------------------------- ekran

  /// Burchakdagi o'yinchi paneli (rang burchagiga mos).
  Widget _panel(int color, {required bool alignRight}) {
    final g = _game;
    if (!g.colors.contains(color)) return const Expanded(child: SizedBox());
    final active = g.current == color && g.phase != LudoPhase.finished;
    final canRoll =
        active && !_busy && !_rolling && g.phase == LudoPhase.roll && !g.isAiTurn;

    final info = Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${kLudoNames[color]}${g.ai.contains(color) ? ' 🤖' : ''}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 0; k < 4; k++)
              Icon(
                k < g.homeCount(color) ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 15,
                color: k < g.homeCount(color) ? const Color(0xFFFFD54F) : Colors.white38,
              ),
          ],
        ),
      ],
    );

    final dice = active
        ? GestureDetector(
            key: const ValueKey('dice'),
            onTap: canRoll ? _roll : null,
            child: _Dice3D(
              value: _face,
              turns: _diceTurns,
              color: kLudoColors[color],
              glowing: canRoll,
            ),
          )
        : const SizedBox(width: 52, height: 52);

    final avatar = SizedBox(
      width: 28,
      height: 38,
      child: CustomPaint(painter: _PawnPainter(kLudoColors[color])),
    );

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [
            kLudoColors[color].withValues(alpha: active ? 0.55 : 0.18),
            kLudoColors[color].withValues(alpha: active ? 0.25 : 0.06),
          ]),
          border: Border.all(
            color: active ? kLudoColors[color] : Colors.white12,
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: kLudoColors[color].withValues(alpha: 0.6), blurRadius: 18)]
              : null,
        ),
        child: LayoutBuilder(builder: (context, box) {
          // Tor ekranda kichik dona rasmi yashiriladi
          final showAvatar = box.maxWidth > 150;
          final mid = [if (showAvatar) ...[avatar, const SizedBox(width: 6)]];
          return Row(
            mainAxisAlignment:
                alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: alignRight
                ? [Flexible(child: info), const SizedBox(width: 6), ...mid, dice]
                : [dice, const SizedBox(width: 6), ...mid, Flexible(child: info)],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return GameScaffold(
      title: 'Ludo',
      palette: GamePalette.ludo,
      actions: [
        IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Qaytadan',
            onPressed: _restart),
      ],
      body: Stack(
        children: [
          LayoutBuilder(builder: (context, box) {
            // Taxta iloji boricha katta, panellar unga yopishib turadi
            final board = min(box.maxWidth - 16, box.maxHeight - 222);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(children: [
                    _panel(0, alignRight: false),
                    const SizedBox(width: 8),
                    _panel(1, alignRight: true),
                  ]),
                ),
                SizedBox(width: board, height: board, child: _buildBoard()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Row(children: [
                    _panel(3, alignRight: false),
                    const SizedBox(width: 8),
                    _panel(2, alignRight: true),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _status,
                      key: ValueKey(_status),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            );
          }),
          if (g.phase == LudoPhase.finished)
            Positioned.fill(
              child: WinOverlay(
                title: '${kLudoNames[g.winner!]} yutdi!',
                subtitle: "4 ta donasini marraga birinchi bo'lib yetkazdi",
                color: kLudoColors[g.winner!],
                actions: [
                  GameButton(
                      label: "Yana o'ynash",
                      icon: Icons.replay_rounded,
                      onPressed: _restart),
                  GameButton(
                    label: 'Bosh menyu',
                    outlined: true,
                    colors: const [Colors.white70, Colors.white70],
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final g = _game;
    final tokens = _display ?? g.tokens;
    final legal = (!_busy && g.phase == LudoPhase.move && !g.isAiTurn)
        ? g.legalTokens().toSet()
        : <int>{};

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LayoutBuilder(builder: (context, box) {
          final s = box.maxWidth / 15;

          // Bir katakdagi donalarni yonma-yon qo'yamiz
          final groups = <(double, double), List<(int, int)>>{};
          for (final c in g.colors) {
            for (var t = 0; t < 4; t++) {
              groups.putIfAbsent(ludoCell(c, t, tokens[c][t]), () => []).add((c, t));
            }
          }

          final widgets = <Widget>[];
          // Faol o'yinchi donalari eng ustida turadi
          final order = [...g.colors.where((c) => c != g.current), g.current];
          for (final c in order) {
            for (var t = 0; t < 4; t++) {
              final p = tokens[c][t];
              final cell = ludoCell(c, t, p);
              final group = groups[cell]!;
              final n = group.indexOf((c, t));
              final crowd = group.length;
              final scale = crowd > 1 ? 0.72 : 1.0;
              final dx = crowd > 1 ? (n - (crowd - 1) / 2) * 0.32 : 0.0;
              final w = s * 0.92 * scale;
              final h = s * 1.2 * scale;
              final isLegal = c == g.current && legal.contains(t);
              final hopping = _hopping == (c, t);

              widgets.add(AnimatedPositioned(
                key: ValueKey('tok-$c-$t'),
                duration: Duration(milliseconds: hopping ? 120 : 260),
                curve: Curves.easeOut,
                left: (cell.$2 + dx) * s - w / 2,
                top: cell.$1 * s - h * 0.82,
                width: w,
                height: h,
                child: GestureDetector(
                  onTap: isLegal ? () => _move(t) : null,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, isLegal ? -s * 0.18 * _pulse.value : 0),
                      child: AnimatedScale(
                        scale: hopping ? 1.2 : 1,
                        duration: const Duration(milliseconds: 100),
                        child: child,
                      ),
                    ),
                    child: CustomPaint(
                      painter: _PawnPainter(kLudoColors[c], highlight: isLegal),
                    ),
                  ),
                ),
              ));
            }
          }

          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
              // Yura oladigan donalar ostida yonib turuvchi halqa
              for (final t in legal)
                Builder(builder: (_) {
                  final cell = ludoCell(g.current, t, tokens[g.current][t]);
                  return Positioned(
                    left: cell.$2 * s - s * 0.6,
                    top: cell.$1 * s - s * 0.6,
                    width: s * 1.2,
                    height: s * 1.2,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5 + 0.5 * _pulse.value),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kLudoColors[g.current].withValues(alpha: 0.8),
                                blurRadius: 10 + 6 * _pulse.value,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ...widgets,
              for (final (key, at, color) in _bursts)
                Positioned(
                  key: key,
                  left: at.$2 * s - s * 2,
                  top: at.$1 * s - s * 2,
                  width: s * 4,
                  height: s * 4,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      builder: (_, v, _) => CustomPaint(painter: _BurstPainter(v, color)),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// Ludo King uslubidagi dona (pin shakli).
class _PawnPainter extends CustomPainter {
  final Color color;
  final bool highlight;
  _PawnPainter(this.color, {this.highlight = false});

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
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color || old.highlight != highlight;
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;
  _BurstPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - t)
        ..color = color.withValues(alpha: 1 - t),
    );
    for (var k = 0; k < 10; k++) {
      final a = k * pi / 5;
      final p = c + Offset(cos(a), sin(a)) * r * t * 0.9;
      canvas.drawCircle(p, 4 * (1 - t), Paint()..color = Colors.white.withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

/// 3D ko'rinishdagi tosh.
class _Dice3D extends StatelessWidget {
  final int value;
  final double turns;
  final Color color;
  final bool glowing;

  const _Dice3D({
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

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 15;
    Rect cell(num r, num c) => Rect.fromLTWH(c * s, r * s, s, s);
    final fill = Paint();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFCFCFD8);

    canvas.drawRect(Offset.zero & size, fill..color = Colors.white);

    // Uychalar
    const corners = [(0, 0), (0, 9), (9, 9), (9, 0)];
    for (var c = 0; c < 4; c++) {
      final (r0, c0) = corners[c];
      final yard = Rect.fromLTWH(c0 * s, r0 * s, 6 * s, 6 * s);
      final col = kLudoColors[c];
      canvas.drawRect(
        yard,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(col, Colors.white, 0.15)!, Color.lerp(col, Colors.black, 0.15)!],
          ).createShader(yard),
      );
      final inner = RRect.fromRectAndRadius(
          Rect.fromLTWH((c0 + 0.75) * s, (r0 + 0.75) * s, 4.5 * s, 4.5 * s),
          Radius.circular(s * 0.6));
      canvas.drawRRect(inner.shift(Offset(0, s * 0.08)), Paint()..color = Colors.black26);
      canvas.drawRRect(inner, Paint()..color = Colors.white);
      for (final (yr, yc) in kLudoYard[c]) {
        final p = Offset(yc * s, yr * s);
        canvas.drawCircle(p, s * 0.62, Paint()..color = col.withValues(alpha: 0.18));
        canvas.drawCircle(
            p,
            s * 0.62,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = col);
      }
    }

    // Umumiy yo'l
    for (var i = 0; i < kLudoPath.length; i++) {
      final (r, c) = kLudoPath[i];
      final start = kLudoStart.indexOf(i);
      canvas.drawRect(cell(r, c), Paint()..color = start >= 0 ? kLudoColors[start] : Colors.white);
      canvas.drawRect(cell(r, c), line);
      if (start >= 0) {
        _arrow(canvas, cell(r, c), start);
      } else if (kLudoSafe.contains(i)) {
        _star(canvas, cell(r, c).center, s * 0.36);
      }
    }
    // Rangli yo'laklar
    final laneLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white54;
    for (var c = 0; c < 4; c++) {
      for (final (r, cc) in kLudoHomeLane[c]) {
        canvas.drawRect(cell(r, cc), Paint()..color = kLudoColors[c]);
        canvas.drawRect(cell(r, cc), laneLine);
      }
    }

    // Markaz: 4 ta uchburchak
    final center = Offset(7.5 * s, 7.5 * s);
    final tl = Offset(6 * s, 6 * s), tr = Offset(9 * s, 6 * s);
    final br = Offset(9 * s, 9 * s), bl = Offset(6 * s, 9 * s);
    final tris = [[tl, bl], [tl, tr], [tr, br], [bl, br]];
    for (var c = 0; c < 4; c++) {
      final path = Path()
        ..moveTo(tris[c][0].dx, tris[c][0].dy)
        ..lineTo(tris[c][1].dx, tris[c][1].dy)
        ..lineTo(center.dx, center.dy)
        ..close();
      final col = kLudoColors[c];
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(colors: [Color.lerp(col, Colors.white, 0.3)!, col])
              .createShader(Rect.fromCircle(center: center, radius: 1.6 * s)),
      );
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white);
    }
    // Markazdagi kubok doirasi
    canvas.drawCircle(center, s * 0.55, fill..color = Colors.white);
    _star(canvas, center, s * 0.4, color: const Color(0xFFFFB300), filled: true);
  }

  void _arrow(Canvas canvas, Rect r, int color) {
    // Har rang o'z yo'nalishiga strelka
    const dirs = [Offset(1, 0), Offset(0, 1), Offset(-1, 0), Offset(0, -1)];
    final d = dirs[color];
    final c = r.center;
    final n = Offset(-d.dy, d.dx);
    final a = r.width * 0.28;
    final path = Path()
      ..moveTo(c.dx + d.dx * a, c.dy + d.dy * a)
      ..lineTo(c.dx - d.dx * a + n.dx * a, c.dy - d.dy * a + n.dy * a)
      ..lineTo(c.dx - d.dx * a - n.dx * a, c.dy - d.dy * a - n.dy * a)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  void _star(Canvas canvas, Offset c, double r,
      {Color color = const Color(0xFF9E9EB0), bool filled = false}) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = -pi / 2 + k * pi / 5;
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
