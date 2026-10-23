import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../net/server_client.dart';
import '../../ui/kit.dart';
import 'stack_game.dart';

const _bestKey = 'stack_best';

enum _Stage { ready, playing, over }

/// Rekordlar jadvalidagi bitta qator.
class _Entry {
  final String uid;
  final String name;
  final int score;
  const _Entry(this.uid, this.name, this.score);
}

/// Stack: bitta bosish bilan minora qurish.
class StackScreen extends StatefulWidget {
  const StackScreen({super.key});

  @override
  State<StackScreen> createState() => _StackScreenState();
}

class _StackScreenState extends State<StackScreen> with SingleTickerProviderStateMixin {
  StackGame _game = StackGame();
  _Stage _stage = _Stage.ready;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  /// Kamera balandligi (qavatlarda, silliq ergashadi).
  double _cam = 0;

  /// "Zo'r!" yozuvi va halqa effekti.
  double _perfectAt = -10;
  int _perfectCombo = 0;

  /// O'yin tugagan payt (natija oynasi biroz kechikib chiqadi).
  double _overAt = 0;

  int _best = 0;
  bool _newRecord = false;

  // Umumiy rekordlar (server)
  StreamSubscription<Doc>? _scoresSub;
  List<_Entry> _top = const [];
  bool get _online => ServerClient.instance.state.value == ConnState.online;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    _loadBest();
    if (_online) {
      _scoresSub = ServerClient.instance.watch('scores/stack').listen((doc) {
        final list = (doc.data()?['top'] as List?) ?? const [];
        setState(() {
          _top = [
            for (final e in list)
              _Entry(e['uid'] as String? ?? '', e['name'] as String? ?? '?', e['score'] as int? ?? 0),
          ];
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scoresSub?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b = prefs.getInt(_bestKey) ?? 0;
      if (!mounted) return;
      setState(() => _best = b);
      // Server qayta ishga tushgan bo'lsa ham rekord jadvalda tursin
      if (b > 0) _submit(b);
    } catch (_) {}
  }

  void _submit(int score) {
    if (!_online) return;
    ServerClient.instance.call('score.submit', {'game': 'stack', 'score': score}).catchError((_) => null);
  }

  Future<void> _saveBest(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, score);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- o'yin

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    if (_stage == _Stage.playing || _game.pieces.isNotEmpty) _game.update(dt);
    // Kamera minora tepasiga silliq ko'tariladi
    _cam += (_game.score - _cam) * min(1.0, dt * 6);
    setState(() {});
  }

  void _tap() {
    switch (_stage) {
      case _Stage.ready:
        setState(() => _stage = _Stage.playing);
        HapticFeedback.selectionClick();
      case _Stage.playing:
        final r = _game.place();
        switch (r) {
          case StackResult.perfect:
            HapticFeedback.mediumImpact();
            _perfectAt = _game.time;
            _perfectCombo = _game.combo;
          case StackResult.placed:
            HapticFeedback.selectionClick();
          case StackResult.missed:
            HapticFeedback.heavyImpact();
            _gameOver();
        }
      case _Stage.over:
        break;
    }
  }

  void _gameOver() {
    final score = _game.score;
    _overAt = _game.time;
    _newRecord = score > _best;
    if (_newRecord) {
      _best = score;
      _saveBest(score);
    }
    _submit(score);
    setState(() => _stage = _Stage.over);
  }

  void _again() {
    setState(() {
      _game = StackGame();
      _stage = _Stage.playing;
      _cam = 0;
      _perfectAt = -10;
      _newRecord = false;
    });
  }

  // ---------------------------------------------------------------- ekran

  /// Qavatga qarab rang (har qavatda biroz o'zgaradi).
  static double _hue(int level) => (200 + level * 7.0) % 360;

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final hue = _hue(_cam.round());
    final bgTop = HSLColor.fromAHSL(1, hue, 0.45, 0.30).toColor();
    final bgBottom = HSLColor.fromAHSL(1, (hue + 50) % 360, 0.55, 0.10).toColor();
    final sincePerfect = g.time - _perfectAt;

    return GameScaffold(
      title: 'Stack',
      palette: GamePalette.stack,
      body: GestureDetector(
        key: const ValueKey('stack'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bgTop, bgBottom],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _TowerPainter(
                  g,
                  cam: _cam,
                  showMoving: _stage == _Stage.playing,
                  ripple: sincePerfect < 0.6 ? sincePerfect / 0.6 : null,
                ),
              ),
            ),
            // Hisob
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      '${g.score}',
                      key: const ValueKey('score'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
                      ),
                    ),
                    if (sincePerfect < 0.9 && _stage == _Stage.playing)
                      Opacity(
                        opacity: (1 - sincePerfect / 0.9).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, -20 * sincePerfect),
                          child: GlowText(
                            _perfectCombo >= 2 ? "Zo'r! ×$_perfectCombo" : "Zo'r!",
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_stage == _Stage.ready)
              Positioned(
                left: 0,
                right: 0,
                top: 120,
                child: IgnorePointer(
                  child: Column(
                    children: [
                      const GlowText('Bosing — boshlang', size: 24, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        "Blokni pastdagisining ustiga to'g'ri qo'ying.\nChiqib turgan qismi kesilib tushadi.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                      ),
                      if (_best > 0) ...[
                        const SizedBox(height: 10),
                        Text('Rekordingiz: $_best',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
              ),
            if (_stage == _Stage.over && g.time - _overAt > 0.9) Positioned.fill(child: _overPanel()),
          ],
        ),
      ),
    );
  }

  Widget _overPanel() {
    final myUid = ServerClient.instance.myUid;
    final top = _top.take(10).toList();
    final myRank = _top.indexWhere((e) => e.uid == myUid);
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Glass(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_game.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
              if (_newRecord)
                const GlowText('🎉 Yangi rekord!', size: 22, color: Color(0xFFFFD54F))
              else
                Text('Rekordingiz: $_best', style: const TextStyle(color: Colors.white70)),
              if (top.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('🏆 Rekordlar jadvali',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 6),
                for (var k = 0; k < top.length; k++) _row(k + 1, top[k], top[k].uid == myUid),
                if (myRank >= 10) ...[
                  const Text('…', style: TextStyle(color: Colors.white38)),
                  _row(myRank + 1, _top[myRank], true),
                ],
              ],
              const SizedBox(height: 18),
              GameButton(
                key: const ValueKey('again'),
                label: "Yana o'ynash",
                icon: Icons.replay_rounded,
                colors: const [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
                onPressed: _again,
              ),
              const SizedBox(height: 10),
              GameButton(
                label: 'Bosh menyu',
                outlined: true,
                colors: const [Colors.white70, Colors.white70],
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int rank, _Entry e, bool me) {
    final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '$rank.' };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: me ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(medal, style: const TextStyle(color: Colors.white70))),
          Expanded(
            child: Text(
              e.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontWeight: me ? FontWeight.w900 : FontWeight.w600),
            ),
          ),
          Text('${e.score}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// Izometrik minora.
class _TowerPainter extends CustomPainter {
  final StackGame g;
  final double cam;
  final bool showMoving;

  /// Aniq qo'yilganda yuqori qavat atrofidagi halqa (0..1).
  final double? ripple;

  _TowerPainter(this.g, {required this.cam, required this.showMoving, this.ripple});

  static const _h = 2.0; // qavat balandligi
  static final _c = cos(pi / 6), _s = sin(pi / 6);

  late double _k;
  late Offset _origin;

  Offset _iso(double x, double y, double z) =>
      _origin + Offset((x - z) * _c * _k, ((x + z) * _s - y) * _k);

  @override
  void paint(Canvas canvas, Size size) {
    _k = size.width * 0.6 / (StackGame.base * 2 * _c);
    // Minora tepasi ekranning ~45% balandligida
    _origin = Offset(size.width / 2, size.height * 0.5 + cam * _h * _k);

    // Pastda "chuqurlikka" ketuvchi asos ustun
    final base = g.tower.first;
    _box(canvas, StackBox(base.x, base.z, base.w, base.d, -12), 0, heightLevels: 12);

    final topLevel = g.score;
    final behind = <StackPiece>[], front = <StackPiece>[];
    for (final p in g.pieces) {
      final t = g.top;
      final pc = p.box.x + p.box.w / 2 + p.box.z + p.box.d / 2;
      final tc = t.x + t.w / 2 + t.z + t.d / 2;
      (pc < tc ? behind : front).add(p);
    }
    for (final p in behind) {
      _piece(canvas, p);
    }
    // Faqat ko'rinadigan qavatlar
    for (final b in g.tower) {
      if (b.level < topLevel - 14) continue;
      _box(canvas, b, b.level);
    }
    if (showMoving && !g.over) _box(canvas, g.moving, g.moving.level);
    for (final p in front) {
      _piece(canvas, p);
    }

    final r = ripple;
    if (r != null) {
      final t = g.top;
      final grow = 0.4 + r * 2.0;
      final y = (t.level + 1) * _h;
      final path = Path()
        ..addPolygon([
          _iso(t.x - grow, y, t.z - grow),
          _iso(t.x + t.w + grow, y, t.z - grow),
          _iso(t.x + t.w + grow, y, t.z + t.d + grow),
          _iso(t.x - grow, y, t.z + t.d + grow),
        ], true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: (1 - r) * 0.9),
      );
    }
  }

  void _piece(Canvas canvas, StackPiece p) {
    final age = g.time - p.born;
    final fall = 0.5 * 30 * age * age; // erkin tushish
    final alpha = (1 - age / 2.5).clamp(0.0, 1.0);
    _box(canvas, p.box, p.box.level, drop: fall, alpha: alpha);
  }

  /// Bitta blok: tepa va ikki ko'rinadigan yon.
  void _box(Canvas canvas, StackBox b, int colorLevel,
      {double drop = 0, double alpha = 1, int heightLevels = 1}) {
    final hue = _StackScreenState._hue(colorLevel);
    Color c(double l) => HSLColor.fromAHSL(alpha, hue, 0.6, l.clamp(0.0, 1.0)).toColor();
    final y0 = b.level * _h - drop, y1 = y0 + _h * heightLevels;
    final x0 = b.x, x1 = b.x + b.w, z0 = b.z, z1 = b.z + b.d;

    final top = [_iso(x0, y1, z0), _iso(x1, y1, z0), _iso(x1, y1, z1), _iso(x0, y1, z1)];
    final right = [_iso(x1, y1, z0), _iso(x1, y1, z1), _iso(x1, y0, z1), _iso(x1, y0, z0)];
    final left = [_iso(x0, y1, z1), _iso(x1, y1, z1), _iso(x1, y0, z1), _iso(x0, y0, z1)];

    canvas.drawPath(Path()..addPolygon(right, true), Paint()..color = c(0.48));
    canvas.drawPath(Path()..addPolygon(left, true), Paint()..color = c(0.38));
    canvas.drawPath(Path()..addPolygon(top, true), Paint()..color = c(0.64));
    // Yuqori qirralarda nozik yorug' chiziq
    canvas.drawPath(
      Path()..addPolygon(top, true),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _TowerPainter old) => true;
}
