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

  /// Kompyuter navbati davom etyapti.
  bool _aiView = false;

  /// Oxirgi otish natijasi har bir taxta uchun: [0] — raqib (katta), [1] — siz (kichik).
  final _shot = <(String, ShotResult)?>[null, null];
  Timer? _timer;

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

  void _showShot(int board, int cell, ShotResult result) {
    _shot[board] = (cellName(cell), result);
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
    setState(() => _showShot(0, cell, result));
    if (result == ShotResult.miss) _later(1000, _startAiTurn);
  }

  void _startAiTurn() {
    setState(() => _aiView = true);
    _later(900, _aiShoot);
  }

  void _aiShoot() {
    if (_game.phase != Phase.battle || _game.current != _ai) return;
    final cell = battleshipAiShot(_game, _ai, widget.level, _rnd);
    final result = _game.fire(cell);
    setState(() => _showShot(1, cell, result));
    if (_game.phase == Phase.finished) return;
    if (result == ShotResult.miss) {
      _later(1100, () => setState(() => _aiView = false));
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
      _shot[0] = _shot[1] = null;
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

  /// Taxta ustida chiqadigan natija: "e5 — Tegdi!" (bir zum ko'rinib, so'nadi).
  Widget _resultBadge(int board, {bool small = false}) {
    final shot = _shot[board];
    if (shot == null) return const SizedBox.shrink();
    final (name, result) = shot;
    final (color, icon) = switch (result) {
      ShotResult.hit => (const Color(0xFFFF7043), Icons.local_fire_department_rounded),
      ShotResult.sunk => (const Color(0xFFFFB300), Icons.whatshot_rounded),
      _ => (const Color(0xFF4FD1FF), Icons.water_drop_rounded),
    };
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey('fx-$board-${_fxId[board]}'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1500),
          builder: (_, t, child) {
            final pop = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
            final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: small ? 10 : 16, vertical: small ? 6 : 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 18)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: small ? 18 : 24),
                const SizedBox(width: 6),
                Text(
                  '$name — ${_resultText(result)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: small ? 16 : 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBattle() {
    final status = _aiView ? 'Kompyuter otyapti…' : 'Sizning navbatingiz — raqib dengiziga oting';
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
        const SizedBox(height: 10),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              status,
              key: ValueKey(status),
              style: TextStyle(
                color: _aiView ? const Color(0xFFFF8A65) : const Color(0xFF9BE7FF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Katta taxta — doim raqib dengizi, natija uning ustida
        _caption('RAQIB DENGIZI'),
        Stack(
          children: [
            _target(big: true),
            Positioned.fill(child: _resultBadge(0)),
          ],
        ),
        const SizedBox(height: 14),
        // Pastda — sizning dengizingiz, kompyuter otganda natija shu yerda
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _caption('SIZNING DENGIZINGIZ'),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _aiView
                          ? [BoxShadow(color: const Color(0xFFFF7043).withValues(alpha: 0.55), blurRadius: 18)]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        _own(big: false),
                        Positioned.fill(child: _resultBadge(1, small: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Glass(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_game.round}-raund',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Tekkizsangiz — yana otasiz.',
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
