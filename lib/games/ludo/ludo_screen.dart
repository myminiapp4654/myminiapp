import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
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
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final colors = LudoGame.colorsFor(players);
      return AlertDialog(
        title: const Text('Ludo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("O'yinchilar"),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {players},
              onSelectionChanged: (s) => setState(() => players = s.first),
            ),
            const SizedBox(height: 12),
            for (final c in colors)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: CircleAvatar(radius: 10, backgroundColor: kLudoColors[c]),
                title: Text(kLudoNames[c]),
                subtitle: Text(ai.contains(c) ? 'Kompyuter' : 'Odam'),
                value: ai.contains(c),
                onChanged: (v) => setState(() => v ? ai.add(c) : ai.remove(c)),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final colors = LudoGame.colorsFor(players);
              Navigator.pop(ctx, (
                players: players,
                ai: ai.where(colors.contains).toSet(),
              ));
            },
            child: const Text('Boshlash'),
          ),
        ],
      );
    }),
  );
}

class LudoScreen extends StatefulWidget {
  final int players;
  final Set<int> ai;

  const LudoScreen({super.key, this.players = 2, this.ai = const {}});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  late LudoGame _game = _newGame();

  /// Animatsiya paytida donalarning ko'rinadigan holati.
  List<List<int>>? _display;
  bool _busy = false;
  bool _rolling = false;
  int _face = 1;
  String _status = '';
  Timer? _aiTimer;

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
      setState(() => _face = rnd.nextInt(6) + 1);
    }
    final v = g.roll();
    setState(() {
      _rolling = false;
      _face = v;
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
      note = '${kLudoNames[color]} ${m.captured.map((c) => kLudoNames[c.$1]).toSet().join(', ')}ni urdi!';
    } else if (m.reachedHome) {
      note = '${kLudoNames[color]} donasi marraga yetdi!';
    }
    setState(() {
      _display = null;
      _busy = false;
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

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final text = Theme.of(context).textTheme;
    final canRoll = !_busy && !_rolling && g.phase == LudoPhase.roll && !g.isAiTurn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludo'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Qaytadan',
              onPressed: _restart),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in g.colors)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: kLudoColors[c]),
                    label: Text('${kLudoNames[c]}${g.ai.contains(c) ? ' 🤖' : ''}  '
                        '${g.homeCount(c)}/4'),
                    side: c == g.current && g.phase != LudoPhase.finished
                        ? BorderSide(color: kLudoColors[c], width: 2)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_status, style: text.titleSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            GestureDetector(
              key: const ValueKey('dice'),
              onTap: canRoll ? _roll : null,
              child: _Dice(
                value: _face,
                color: kLudoColors[g.current],
                active: canRoll,
              ),
            ),
            const SizedBox(height: 4),
            if (g.phase == LudoPhase.finished)
              FilledButton(onPressed: _restart, child: const Text("Yana o'ynash"))
            else
              Text(canRoll ? 'Toshni bosing' : ' ', style: text.bodySmall),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final g = _game;
    final tokens = _display ?? g.tokens;
    final legal = (!_busy && g.phase == LudoPhase.move && !g.isAiTurn)
        ? g.legalTokens().toSet()
        : <int>{};

    return LayoutBuilder(builder: (context, box) {
      final s = box.maxWidth / 15;

      // Bir katakdagi donalarni biroz surib qo'yamiz
      final placed = <(double, double), int>{};
      final widgets = <Widget>[];
      for (final c in g.colors) {
        for (var t = 0; t < 4; t++) {
          final p = tokens[c][t];
          final cell = ludoCell(c, t, p);
          final n = placed.update(cell, (v) => v + 1, ifAbsent: () => 0);
          final shift = n * 0.18;
          final size = s * (p == -1 ? 0.9 : 0.78);
          final isLegal = c == g.current && legal.contains(t);
          widgets.add(AnimatedPositioned(
            key: ValueKey('tok-$c-$t'),
            duration: const Duration(milliseconds: 120),
            left: (cell.$2 + shift) * s - size / 2,
            top: (cell.$1 - shift) * s - size / 2,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: isLegal ? () => _move(t) : null,
              child: _Token(color: kLudoColors[c], highlight: isLegal),
            ),
          ));
        }
      }
      return Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
          ...widgets,
        ],
      );
    });
  }
}

class _Token extends StatelessWidget {
  final Color color;
  final bool highlight;

  const _Token({required this.color, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [Color.lerp(color, Colors.white, 0.4)!, color],
        ),
        border: Border.all(
          color: highlight ? Colors.white : Colors.black54,
          width: highlight ? 3 : 1.5,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: color.withValues(alpha: 0.9), blurRadius: 8, spreadRadius: 2)]
            : const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))],
      ),
    );
  }
}

class _Dice extends StatelessWidget {
  final int value;
  final Color color;
  final bool active;

  const _Dice({required this.value, required this.color, required this.active});

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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: active ? 4 : 2),
      ),
      child: Stack(
        children: [
          for (final (r, c) in _dots[value]!)
            Align(
              alignment: Alignment(c - 1.0, r - 1.0),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Colors.black87, shape: BoxShape.circle),
              ),
            ),
        ],
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
      ..strokeWidth = 0.8
      ..color = Colors.black26;

    canvas.drawRect(Offset.zero & size, fill..color = const Color(0xFFFAFAFA));

    // Uychalar
    const corners = [(0, 0), (0, 9), (9, 9), (9, 0)];
    for (var c = 0; c < 4; c++) {
      final (r0, c0) = corners[c];
      canvas.drawRect(Rect.fromLTWH(c0 * s, r0 * s, 6 * s, 6 * s),
          fill..color = kLudoColors[c]);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH((c0 + 0.8) * s, (r0 + 0.8) * s, 4.4 * s, 4.4 * s),
              Radius.circular(s * 0.4)),
          fill..color = Colors.white);
      for (final (yr, yc) in kLudoYard[c]) {
        canvas.drawCircle(Offset(yc * s, yr * s), s * 0.55,
            fill..color = kLudoColors[c].withValues(alpha: 0.35));
      }
    }

    // Umumiy yo'l
    for (var i = 0; i < kLudoPath.length; i++) {
      final (r, c) = kLudoPath[i];
      final start = kLudoStart.indexOf(i);
      canvas.drawRect(cell(r, c),
          fill..color = start >= 0 ? kLudoColors[start] : Colors.white);
      canvas.drawRect(cell(r, c), line);
      if (kLudoSafe.contains(i) && start < 0) {
        _star(canvas, cell(r, c).center, s * 0.32);
      }
    }
    // Rangli yo'laklar
    for (var c = 0; c < 4; c++) {
      for (final (r, cc) in kLudoHomeLane[c]) {
        canvas.drawRect(cell(r, cc), fill..color = kLudoColors[c]);
        canvas.drawRect(cell(r, cc), line);
      }
    }
    // Markaz: 4 ta uchburchak (har rang o'z tomonida)
    final center = Offset(7.5 * s, 7.5 * s);
    final tl = Offset(6 * s, 6 * s), tr = Offset(9 * s, 6 * s);
    final br = Offset(9 * s, 9 * s), bl = Offset(6 * s, 9 * s);
    final tris = [
      [tl, bl], // qizil — chap
      [tl, tr], // yashil — yuqori
      [tr, br], // sariq — o'ng
      [bl, br], // ko'k — past
    ];
    for (var c = 0; c < 4; c++) {
      final path = Path()
        ..moveTo(tris[c][0].dx, tris[c][0].dy)
        ..lineTo(tris[c][1].dx, tris[c][1].dy)
        ..lineTo(center.dx, center.dy)
        ..close();
      canvas.drawPath(path, fill..color = kLudoColors[c]);
    }
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = -pi / 2 + k * pi / 5;
      final p = c + Offset(cos(a) * rr, sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.black38);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
