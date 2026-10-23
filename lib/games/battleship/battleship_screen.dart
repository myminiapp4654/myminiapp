import 'package:flutter/material.dart';

import 'battleship_game.dart';
import 'battleship_placement.dart';
import 'sea_art.dart';
import '../../ui/game_art.dart';
import '../../ui/kit.dart';

/// Dengiz jangi: bitta telefonda ikki kishi.
/// Navbat almashganda telefon uzatiladi — raqib kemalarni ko'rmasligi uchun
/// oraliq "yopiq" ekran chiqadi.
class BattleshipScreen extends StatefulWidget {
  const BattleshipScreen({super.key});

  @override
  State<BattleshipScreen> createState() => _BattleshipScreenState();
}

class _BattleshipScreenState extends State<BattleshipScreen> {
  final _game = BattleshipGame();

  /// Hozir telefonni ushlab turgan o'yinchi.
  int _viewer = 0;

  /// Telefonni keyingi o'yinchiga uzatish ekrani ko'rsatilyaptimi.
  bool _covered = true;

  /// Tegmadi — navbatni o'tkazish kutilmoqda.
  bool _awaitingPass = false;

  /// Oxirgi otish natijasi (ekranda ko'rsatish uchun).
  String? _lastShot;
  ShotResult? _lastResult;

  /// Otish effekti: katak, tekdimi, tartib raqami.
  int? _fxCell;
  bool _fxHit = false;
  int _fxId = 0;

  static String _name(int p) => '${p + 1}-o\'yinchi';

  void _open() => setState(() {
        _viewer = _game.current;
        _covered = false;
        _awaitingPass = false;
        _lastShot = null;
        _lastResult = null;
        _fxCell = null;
      });

  // ---------------------------------------------------------------- joylashtirish

  void _donePlacing() => setState(() {
        _game.finishPlacing();
        _covered = true;
      });

  // ---------------------------------------------------------------- jang

  void _fire(int cell) {
    if (_awaitingPass) return;
    final result = _game.fire(cell);
    if (result == ShotResult.repeat) return;
    setState(() {
      _lastShot = '${cellName(cell)} — ${switch (result) {
        ShotResult.miss => 'Tegmadi',
        ShotResult.hit => 'Tegdi!',
        ShotResult.sunk => 'Portladi!',
        ShotResult.repeat => '',
      }}';
      if (result == ShotResult.miss) _awaitingPass = true;
      _lastResult = result;
      _fxCell = cell;
      _fxHit = result != ShotResult.miss;
      _fxId++;
    });
  }

  void _pass() => setState(() => _covered = true);

  void _newRound() => setState(() {
        _game.newRound();
        _covered = true;
        _lastShot = null;
      });

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_game.phase == Phase.finished) {
      body = _buildFinished();
    } else if (_covered) {
      body = _buildCover();
    } else if (_game.phase == Phase.placing) {
      body = _buildPlacing();
    } else {
      body = _buildBattle();
    }
    return GameScaffold(
      title: 'Dengiz jangi',
      palette: GamePalette.sea,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey('${_game.phase}-$_covered-$_viewer'),
          child: body,
        ),
      ),
    );
  }

  Widget _buildCover() {
    final next = _game.current;
    final what = _game.phase == Phase.placing ? 'kemalarini joylashtiradi' : 'otadi';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                builder: (_, t, _) =>
                    CustomPaint(painter: GameArtPainter(GameArt.battleship, t)),
              ),
            ),
            const SizedBox(height: 12),
            GlowText('Telefonni ${_name(next)}ga bering',
                size: 24, color: const Color(0xFF9BE7FF)),
            const SizedBox(height: 8),
            Text('${_name(next)} $what. Raqib qaramasin!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            if (_game.round > 1 || _game.score.any((x) => x > 0)) ...[
              const SizedBox(height: 8),
              Text('Hisob ${_game.score[0]} : ${_game.score[1]}',
                  style: const TextStyle(color: Colors.white54)),
            ],
            const SizedBox(height: 28),
            GameButton(
              key: const ValueKey('open'),
              label: 'Men ${_name(next)}man',
              icon: Icons.visibility_rounded,
              colors: const [Color(0xFF4FD1FF), Color(0xFF1565C0)],
              expand: false,
              onPressed: _open,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacing() => BattleshipPlacement(
        key: ValueKey('placing-$_viewer-${_game.round}'),
        fleet: _game.fleets[_viewer],
        title: '${_name(_viewer)}: kemalarni joylashtiring',
        onReady: _donePlacing,
      );

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

  Widget _buildBattle() {
    final me = _viewer;
    final (bannerColor, bannerIcon) = switch (_lastResult) {
      ShotResult.hit => (const Color(0xFFFF7043), Icons.local_fire_department_rounded),
      ShotResult.sunk => (const Color(0xFFFFB300), Icons.whatshot_rounded),
      ShotResult.miss => (const Color(0xFF4FD1FF), Icons.water_drop_rounded),
      _ => (Colors.white54, Icons.gps_fixed_rounded),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      children: [
        Row(
          children: [
            Flexible(
              child: PlayerBadge(
                color: const Color(0xFF4FD1FF),
                name: '${_name(me)} otadi',
                active: true,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Raqib kemalari',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 3),
                _fleetIcons(1 - me),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Row(
            key: ValueKey(_lastShot),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(bannerIcon, color: bannerColor, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: GlowText(_lastShot ?? 'Raqib taxtasidan katak tanlang',
                    size: _lastShot == null ? 17 : 24, color: bannerColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SeaGrid(
          keyPrefix: 'target',
          cell: (i) => _targetCell(i, me),
          onTap: _awaitingPass ? null : _fire,
          effectCell: _fxCell,
          effectHit: _fxHit,
          effectId: _fxId,
        ),
        const SizedBox(height: 14),
        if (_awaitingPass)
          GameButton(
            key: const ValueKey('pass'),
            label: "Navbatni o'tkazish",
            icon: Icons.swap_horiz_rounded,
            colors: const [Color(0xFF4FD1FF), Color(0xFF1565C0)],
            onPressed: _pass,
          ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SeaGrid(
                keyPrefix: 'own',
                small: true,
                cell: (i) => _ownCell(i, me),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sizning flotingiz',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    _fleetIcons(me),
                    const SizedBox(height: 10),
                    Text('Hisob: ${_game.score[0]} : ${_game.score[1]}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('${_game.round}-raund',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final w = _game.winner!;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
          children: [
            for (final p in [0, 1]) ...[
              Text('${_name(p)} kemalari',
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
            title: '${_name(w)} yutdi!',
            subtitle: 'Hisob ${_game.score[0]} : ${_game.score[1]}  •  ${_game.round}-raund',
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
