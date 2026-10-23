import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'battleship_ai.dart';
import 'battleship_game.dart';
import 'battleship_placement.dart';
import 'sea_art.dart';
import '../../ui/kit.dart';

/// Dengiz jangi: siz kompyuterga qarshi.
///
/// Siz kemalaringizni joylashtirasiz, kompyuter o'zinikini yashirincha qo'yadi.
/// Navbatingizda raqib dengiziga otasiz, kompyuter navbatida esa
/// katta taxtada o'z dengizingiz va unga tushayotgan o'qlar ko'rinadi.
class BattleshipScreen extends StatefulWidget {
  /// Kompyuter darajasi: 1 — oson, 2 — o'rta, 3 — qiyin
  final int level;

  /// Testlar uchun
  final int? seed;

  const BattleshipScreen({super.key, this.level = 2, this.seed});

  @override
  State<BattleshipScreen> createState() => _BattleshipScreenState();
}

class _BattleshipScreenState extends State<BattleshipScreen> {
  static const _me = 0, _ai = 1;
  final _game = BattleshipGame();
  late final Random _rnd = Random(widget.seed);

  /// Katta taxtada kompyuter otishi ko'rsatilyaptimi.
  bool _aiView = false;
  Timer? _timer;

  /// Oxirgi otish natijasi (banner uchun).
  String? _banner;
  ShotResult? _lastResult;

  /// Otish effektlari: [0] — raqib taxtasida, [1] — mening taxtamda.
  final _fxCell = <int?>[null, null];
  final _fxHit = [false, false];
  final _fxId = [0, 0];

  @override
  void initState() {
    super.initState();
    _aiPlaceIfNeeded();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _myTurn =>
      _game.phase == Phase.battle && _game.current == _me && !_aiView && _timer == null;

  // ---------------------------------------------------------------- joylashtirish

  /// Kompyuter kemalarini yashirincha joylashtiradi.
  void _aiPlaceIfNeeded() {
    if (_game.phase == Phase.placing && _game.current == _ai) {
      _game.fleets[_ai].randomize(_rnd);
      _game.finishPlacing();
    }
  }

  void _donePlacing() {
    setState(() {
      _game.finishPlacing();
      _aiPlaceIfNeeded();
      _banner = null;
      _lastResult = null;
    });
    // Kompyuter boshlasa
    if (_game.phase == Phase.battle && _game.current == _ai) {
      _later(500, _startAiTurn);
    }
  }

  // ---------------------------------------------------------------- jang

  void _later(int ms, VoidCallback f) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: ms), () {
      _timer = null;
      if (mounted) f();
    });
  }

  String _resultText(ShotResult r) => switch (r) {
        ShotResult.miss => 'Tegmadi',
        ShotResult.hit => 'Tegdi!',
        ShotResult.sunk => 'Portladi!',
        ShotResult.repeat => '',
      };

  void _showShot(int board, int cell, ShotResult result, String prefix) {
    _banner = '$prefix${cellName(cell)} — ${_resultText(result)}';
    _lastResult = result;
    _fxCell[board] = cell;
    _fxHit[board] = result != ShotResult.miss;
    _fxId[board]++;
    if (result == ShotResult.miss) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _fire(int cell) {
    if (!_myTurn) return;
    final result = _game.fire(cell);
    if (result == ShotResult.repeat) return;
    setState(() => _showShot(0, cell, result, ''));
    if (result == ShotResult.miss) _later(1000, _startAiTurn);
  }

  void _startAiTurn() {
    setState(() {
      _aiView = true;
      _banner = "Kompyuter nishonga olyapti…";
      _lastResult = null;
    });
    _later(900, _aiShoot);
  }

  void _aiShoot() {
    if (_game.phase != Phase.battle || _game.current != _ai) return;
    final cell = battleshipAiShot(_game, _ai, widget.level, _rnd);
    final result = _game.fire(cell);
    setState(() => _showShot(1, cell, result, 'Kompyuter: '));
    if (_game.phase == Phase.finished) return;
    if (result == ShotResult.miss) {
      _later(1100, () => setState(() {
            _aiView = false;
            _banner = null;
            _lastResult = null;
          }));
    } else {
      _later(850, _aiShoot);
    }
  }

  void _newRound() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _game.newRound();
      _aiPlaceIfNeeded();
      _aiView = false;
      _banner = null;
      _lastResult = null;
      _fxCell[0] = _fxCell[1] = null;
    });
  }

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_game.phase) {
      Phase.placing => BattleshipPlacement(
          key: ValueKey('placing-${_game.round}'),
          fleet: _game.fleets[_me],
          title: 'Kemalaringizni joylashtiring',
          onReady: _donePlacing,
        ),
      Phase.battle => _buildBattle(),
      Phase.finished => _buildFinished(),
    };
    return GameScaffold(
      title: 'Dengiz jangi',
      palette: GamePalette.sea,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey('${_game.phase}-${_game.round}'), child: body),
      ),
    );
  }

  /// Raqib taxtasi: men otgan joylar. Kema shakli faqat portlaganda ochiladi.
  (CellView, ShipSeg?) _targetCell(int i, int shooter) {
    final fired = _game.shots[shooter];
    final enemy = _game.fleets[1 - shooter];
    if (fired.contains(i)) {
      final ship = enemy.shipAt(i);
      if (ship == null) return (CellView.miss, null);
      return ship.cells.every(fired.contains)
          ? (CellView.sunk, ShipSeg.of(enemy, i))
          : (CellView.hit, null);
    }
    if (_game.autoMarked[shooter].contains(i)) return (CellView.mark, null);
    return (CellView.water, null);
  }

  /// O'z taxtam: kemalarim va raqib otgan joylar.
  (CellView, ShipSeg?) _ownCell(int i, int owner) {
    final fleet = _game.fleets[owner];
    final seg = ShipSeg.of(fleet, i);
    final enemyShots = _game.shots[1 - owner];
    if (seg != null) {
      final ship = fleet.shipAt(i)!;
      if (ship.cells.every(enemyShots.contains)) return (CellView.sunk, seg);
      return (enemyShots.contains(i) ? CellView.hit : CellView.ship, seg);
    }
    return (enemyShots.contains(i) ? CellView.miss : CellView.water, null);
  }

  Widget _fleetIcons(int player) {
    final alive = _game.shipsAlive(player);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < kFleet.length; k++)
          Container(
            width: 6,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: k < alive ? const Color(0xFF9BD8FF) : Colors.white12,
            ),
          ),
      ],
    );
  }

  Widget _side(String name, int player, bool active, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        PlayerBadge(
          color: player == _me ? const Color(0xFF4FD1FF) : const Color(0xFFFF7043),
          name: name,
          active: active,
          avatar: Icon(
            player == _me ? Icons.person_rounded : Icons.smart_toy_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        _fleetIcons(player),
      ],
    );
  }

  Widget _target({required bool big}) => SeaGrid(
        key: const ValueKey('grid-target'),
        keyPrefix: 'target',
        small: !big,
        cell: (i) => _targetCell(i, _me),
        onTap: big && _myTurn ? _fire : null,
        effectCell: _fxCell[0],
        effectHit: _fxHit[0],
        effectId: _fxId[0],
      );

  Widget _own({required bool big}) => SeaGrid(
        key: const ValueKey('grid-own'),
        keyPrefix: 'own',
        small: !big,
        cell: (i) => _ownCell(i, _me),
        effectCell: _fxCell[1],
        effectHit: _fxHit[1],
        effectId: _fxId[1],
      );

  Widget _caption(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
      );

  Widget _buildBattle() {
    final (bannerColor, bannerIcon) = switch (_lastResult) {
      ShotResult.hit => (const Color(0xFFFF7043), Icons.local_fire_department_rounded),
      ShotResult.sunk => (const Color(0xFFFFB300), Icons.whatshot_rounded),
      ShotResult.miss => (const Color(0xFF4FD1FF), Icons.water_drop_rounded),
      _ => (Colors.white54, Icons.gps_fixed_rounded),
    };
    final banner = _banner ?? 'Raqib dengizidan katak tanlang';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      children: [
        Row(
          children: [
            Flexible(child: _side('Siz', _me, !_aiView, CrossAxisAlignment.start)),
            const SizedBox(width: 10),
            Text('${_game.score[0]} : ${_game.score[1]}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(width: 10),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: _side('Kompyuter', _ai, _aiView, CrossAxisAlignment.end),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Row(
              key: ValueKey(banner),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(bannerIcon, color: bannerColor, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GlowText(banner, size: _banner == null ? 17 : 22, color: bannerColor),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Katta taxta: navbatingizda — raqib dengizi, kompyuter navbatida — sizniki
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (c, a) => ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(a),
            child: FadeTransition(opacity: a, child: c),
          ),
          child: Column(
            key: ValueKey('big-$_aiView'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _caption(_aiView ? 'SIZNING DENGIZINGIZ' : 'RAQIB DENGIZI'),
              _aiView ? _own(big: true) : _target(big: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _caption(_aiView ? 'Raqib dengizi' : 'Sizning dengizingiz'),
                  _aiView ? _target(big: false) : _own(big: false),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_game.round}-raund',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Tekkizsangiz — yana otasiz. Kema portlasa, atrofi belgilanadi.',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final iWon = _game.winner == _me;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          children: [
            for (final (p, name) in const [(_me, 'Sizning'), (_ai, 'Kompyuter')]) ...[
              Text('$name kemalari',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: 0.75,
                child: SeaGrid(keyPrefix: 'final$p', small: true, cell: (i) => _ownCell(i, p)),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
        Positioned.fill(
          child: WinOverlay(
            title: iWon ? 'Siz yutdingiz!' : 'Kompyuter yutdi',
            subtitle: 'Hisob ${_game.score[0]} : ${_game.score[1]}  •  ${_game.round}-raund',
            confetti: iWon,
            color: const Color(0xFF4FD1FF),
            actions: [
              GameButton(
                label: "Yana o'ynash",
                icon: Icons.replay_rounded,
                colors: const [Color(0xFF4FD1FF), Color(0xFF1565C0)],
                onPressed: _newRound,
              ),
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
    );
  }
}
