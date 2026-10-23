import 'package:flutter/material.dart';

import 'battleship_game.dart';

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

  // Joylashtirish
  bool _horizontal = true;
  int? _length;

  /// Oxirgi otish natijasi (ekranda ko'rsatish uchun).
  String? _lastShot;

  static String _name(int p) => '${p + 1}-o\'yinchi';

  void _open() => setState(() {
        _viewer = _game.current;
        _covered = false;
        _awaitingPass = false;
        _lastShot = null;
      });

  // ---------------------------------------------------------------- joylashtirish

  void _placeTap(int cell) {
    final fleet = _game.fleets[_viewer];
    if (fleet.shipAt(cell) != null) {
      setState(() => fleet.removeAt(cell));
      return;
    }
    final remaining = fleet.remaining;
    if (remaining.isEmpty) return;
    final length =
        _length != null && remaining.contains(_length) ? _length! : remaining.first;
    if (!fleet.place(cell, length, _horizontal)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text("Bu yerga qo'yib bo'lmaydi (chetga chiqadi yoki boshqa kemaga tegadi)"),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    setState(() {
      if (!fleet.remaining.contains(_length)) _length = null;
    });
  }

  void _donePlacing() => setState(() {
        _game.finishPlacing();
        _covered = true;
        _length = null;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Dengiz jangi')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildCover() {
    final next = _game.current;
    final what = _game.phase == Phase.placing
        ? 'kemalarini joylashtiradi'
        : 'otadi';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 48),
            const SizedBox(height: 16),
            Text('Telefonni ${_name(next)}ga bering',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${_name(next)} $what'),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('open'),
              onPressed: _open,
              child: Text('Men ${_name(next)}man'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacing() {
    final fleet = _game.fleets[_viewer];
    final remaining = fleet.remaining;
    final lengths = remaining.toSet().toList()..sort((a, b) => b - a);
    final selected =
        _length != null && remaining.contains(_length) ? _length : remaining.firstOrNull;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${_name(_viewer)}: kemalarni joylashtiring',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text("Katakni bosing — kema shu yerdan boshlanadi. "
            "Kemani bossangiz — olib tashlanadi."),
        const SizedBox(height: 12),
        if (remaining.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final l in lengths)
                ChoiceChip(
                  label: Text('$l katak × ${remaining.where((x) => x == l).length}'),
                  selected: l == selected,
                  onSelected: (_) => setState(() => _length = l),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Gorizontal')),
              ButtonSegment(value: false, label: Text('Vertikal')),
            ],
            selected: {_horizontal},
            onSelectionChanged: (s) => setState(() => _horizontal = s.first),
          ),
        ] else
          const Text("Hamma kemalar joyida!"),
        const SizedBox(height: 12),
        _Grid(
          keyPrefix: 'place',
          cellColor: (i) => fleet.shipAt(i) != null ? scheme.primary : null,
          onTap: _placeTap,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(fleet.randomize),
                child: const Text('Tasodifiy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(fleet.clear),
                child: const Text('Tozalash'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('ready'),
          onPressed: fleet.complete ? _donePlacing : null,
          child: const Text('Tayyor'),
        ),
      ],
    );
  }

  /// Raqib taxtasi: men otgan joylar.
  Color? _targetColor(int i, int shooter) {
    final fired = _game.shots[shooter];
    final enemy = _game.fleets[1 - shooter];
    if (fired.contains(i)) {
      final ship = enemy.shipAt(i);
      if (ship == null) return Colors.blueGrey.shade700;
      return ship.cells.every(fired.contains)
          ? Colors.red.shade900
          : Colors.red.shade400;
    }
    if (_game.autoMarked[shooter].contains(i)) return Colors.blueGrey.shade800;
    return null;
  }

  String _targetMark(int i, int shooter) {
    if (_game.shots[shooter].contains(i)) {
      return _game.fleets[1 - shooter].shipAt(i) != null ? '✕' : '•';
    }
    return _game.autoMarked[shooter].contains(i) ? '·' : '';
  }

  /// O'z taxtam: kemalarim va raqib otgan joylar.
  Color? _ownColor(int i, int owner) {
    final ship = _game.fleets[owner].shipAt(i);
    final hit = _game.shots[1 - owner].contains(i);
    if (ship != null) return hit ? Colors.red.shade400 : Colors.blueGrey.shade400;
    return hit ? Colors.blueGrey.shade700 : null;
  }

  Widget _buildBattle() {
    final me = _viewer;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${_name(me)} otadi', style: text.titleMedium),
        Text('Raqibda qolgan kemalar: ${_game.shipsAlive(1 - me)}  •  '
            'sizda: ${_game.shipsAlive(me)}'),
        const SizedBox(height: 8),
        Text(_lastShot ?? 'Raqib taxtasidan katak tanlang',
            style: text.titleLarge),
        const SizedBox(height: 8),
        _Grid(
          keyPrefix: 'target',
          cellColor: (i) => _targetColor(i, me),
          cellText: (i) => _targetMark(i, me),
          onTap: _awaitingPass ? null : _fire,
        ),
        const SizedBox(height: 12),
        if (_awaitingPass)
          FilledButton(
            key: const ValueKey('pass'),
            onPressed: _pass,
            child: const Text("Navbatni o'tkazish"),
          ),
        const SizedBox(height: 16),
        Text('Sizning kemalaringiz', style: text.titleSmall),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: _Grid(
            keyPrefix: 'own',
            small: true,
            cellColor: (i) => _ownColor(i, me),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final w = _game.winner!;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('${_name(w)} yutdi!', style: text.headlineSmall),
        Text('Hisob: ${_game.score[0]} : ${_game.score[1]}  •  ${_game.round}-raund'),
        const SizedBox(height: 12),
        for (final p in [0, 1]) ...[
          Text('${_name(p)} kemalari', style: text.titleSmall),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: 0.7,
            child: _Grid(
              keyPrefix: 'final$p',
              small: true,
              cellColor: (i) => _ownColor(i, p),
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(onPressed: _newRound, child: const Text("Yana o'ynash")),
      ],
    );
  }
}

/// 9×9 taxta, ustida a–i, chap tomonda 1–9.
class _Grid extends StatelessWidget {
  final String keyPrefix;
  final Color? Function(int i) cellColor;
  final String Function(int i)? cellText;
  final void Function(int i)? onTap;
  final bool small;

  const _Grid({
    required this.keyPrefix,
    required this.cellColor,
    this.cellText,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(fontSize: small ? 9 : 12, color: scheme.outline);

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: kBoardSize + 1,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: (kBoardSize + 1) * (kBoardSize + 1),
        itemBuilder: (context, k) {
          final row = k ~/ (kBoardSize + 1), col = k % (kBoardSize + 1);
          if (row == 0 && col == 0) return const SizedBox();
          if (row == 0) {
            return Center(child: Text('abcdefghi'[col - 1], style: labelStyle));
          }
          if (col == 0) return Center(child: Text('$row', style: labelStyle));

          final i = (row - 1) * kBoardSize + (col - 1);
          return Material(
            color: cellColor(i) ?? scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(small ? 1 : 3),
            child: InkWell(
              key: ValueKey('$keyPrefix-$i'),
              onTap: onTap == null ? null : () => onTap!(i),
              child: Center(
                child: Text(cellText?.call(i) ?? '',
                    style: TextStyle(fontSize: small ? 8 : 14)),
              ),
            ),
          );
        },
      ),
    );
  }
}
