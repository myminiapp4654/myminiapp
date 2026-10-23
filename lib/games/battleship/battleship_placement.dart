import 'dart:math';

import 'package:flutter/material.dart';

import 'battleship_game.dart';

/// Sudralayotgan kema.
class _Drag {
  final int length;
  final bool horizontal;

  /// Taxtadan ko'chirilayotgan bo'lsa — asl kema (portdan bo'lsa null).
  final Ship? from;

  const _Drag(this.length, this.horizontal, [this.from]);
}

bool _isHorizontal(Ship s) => s.length == 1 || s.cells[1] - s.cells[0] == 1;

/// Kemalarni joylashtirish: kemalar pastdagi portda turadi,
/// barmoq bilan sudrab taxtaga qo'yiladi.
///  - taxtadagi kemani bosish — burish
///  - taxtadagi kemani sudrash — ko'chirish, taxtadan tashqariga tashlash — portga qaytarish
class BattleshipPlacement extends StatefulWidget {
  final Fleet fleet;
  final String title;
  final VoidCallback onReady;

  const BattleshipPlacement({
    super.key,
    required this.fleet,
    required this.title,
    required this.onReady,
  });

  @override
  State<BattleshipPlacement> createState() => _BattleshipPlacementState();
}

class _BattleshipPlacementState extends State<BattleshipPlacement> {
  final _boardKey = GlobalKey();

  /// Portdagi kemalar qaysi yo'nalishda qo'yiladi.
  bool _horizontal = true;

  /// Sudrash paytidagi ko'rinish: qayerga tushadi va mumkinmi.
  int? _hoverStart;
  _Drag? _hoverDrag;
  bool _hoverValid = false;

  /// Hozir sudralayotgan (taxtadan ko'chirilayotgan) kema.
  Ship? _lifted;

  Fleet get _fleet => widget.fleet;

  // ---------------------------------------------------------------- qoidalar

  /// [d] kemasini [start] dan boshlab qo'yish mumkinmi
  /// (ko'chirilayotgan kemaning o'zi hisobga olinmaydi).
  bool _valid(_Drag d, int start) {
    final own = d.from;
    if (own != null) _fleet.ships.remove(own);
    final ok = _fleet.canPlace(start, d.length, d.horizontal);
    if (own != null) _fleet.ships.add(own);
    return ok;
  }

  bool _put(_Drag d, int start) {
    if (!_valid(d, start)) return false;
    if (d.from != null) _fleet.ships.remove(d.from);
    return _fleet.place(start, d.length, d.horizontal);
  }

  void _rotate(Ship ship) {
    final d = _Drag(ship.length, !_isHorizontal(ship), ship);
    if (!_put(d, ship.cells.first)) {
      _toast("Burib bo'lmaydi — chetga chiqadi yoki boshqa kemaga tegadi");
    }
    setState(() {});
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  // ---------------------------------------------------------------- sudrash

  /// Kema tasvirining chap-yuqori burchagi qaysi katakka tushadi.
  int? _startAt(Offset feedbackTopLeft, double cs) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(feedbackTopLeft + Offset(cs / 2, cs / 2));
    final col = (local.dx / cs).floor() - 1; // 1-ustun — harflar
    final row = (local.dy / cs).floor() - 1; // 1-qator — raqamlar
    if (row < 0 || row >= kBoardSize || col < 0 || col >= kBoardSize) {
      return null;
    }
    return row * kBoardSize + col;
  }

  void _hover(_Drag d, Offset topLeft, double cs) {
    final start = _startAt(topLeft, cs);
    setState(() {
      _hoverDrag = d;
      _hoverStart = start;
      _hoverValid = start != null && _valid(d, start);
    });
  }

  void _clearHover() => setState(() {
        _hoverStart = null;
        _hoverDrag = null;
      });

  /// Barmoq kemaning [grab]-katagida turgandek ko'rinishi uchun.
  static Offset _anchor(Offset inCell, int grab, bool horizontal, double cs) =>
      horizontal
          ? Offset(grab * cs + inCell.dx, inCell.dy)
          : Offset(inCell.dx, grab * cs + inCell.dy);

  Set<int> get _previewCells {
    final d = _hoverDrag, s = _hoverStart;
    if (d == null || s == null) return const {};
    return (Fleet.cellsFor(s, d.length, d.horizontal) ?? const []).toSet();
  }

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, box) {
      // Katak o'lchami: taxta (10 katak) + port (~3 qator) + tugmalar sig'sin
      // (chetdagi 12 px bo'shliqlar ayirib tashlanadi)
      // Balandlik: sarlavha ~50, port sarlavhasi ~48, tugmalar ~104, bo'shliqlar ~40,
      // taxta 10 katak, port kemalari ~3 qator (har biri 1.3 katak)
      final cs = min((box.maxWidth - 24) / (kBoardSize + 1),
              (box.maxHeight - 245) / (kBoardSize + 1 + 3.9))
          .clamp(16.0, 60.0);

      // Juda kichik ekranda sig'masa — aylantirib ko'rish mumkin
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Text(widget.title, style: text.titleMedium),
            const Text("Kemani sudrab taxtaga qo'ying. Bossangiz — buriladi.",
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Center(child: _buildBoard(cs)),
            const SizedBox(height: 10),
            _buildPort(cs),
            const SizedBox(height: 12),
            _buildButtons(),
          ],
        ),
      );
    });
  }

  Widget _buildBoard(double cs) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _previewCells;
    final labelStyle = TextStyle(fontSize: cs * 0.38, color: scheme.outline);

    return DragTarget<_Drag>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (d) => _hover(d.data, d.offset, cs),
      onLeave: (_) => _clearHover(),
      onAcceptWithDetails: (d) {
        final start = _startAt(d.offset, cs);
        if (start == null || !_put(d.data, start)) {
          _toast("Bu yerga qo'yib bo'lmaydi");
        }
        _clearHover();
      },
      builder: (context, _, _) => SizedBox(
        key: _boardKey,
        width: cs * (kBoardSize + 1),
        height: cs * (kBoardSize + 1),
        child: Column(
          children: [
            Row(children: [
              SizedBox(width: cs, height: cs),
              for (var c = 0; c < kBoardSize; c++)
                SizedBox(
                  width: cs,
                  height: cs,
                  child: Center(child: Text('abcdefghi'[c], style: labelStyle)),
                ),
            ]),
            for (var r = 0; r < kBoardSize; r++)
              Row(children: [
                SizedBox(
                  width: cs,
                  height: cs,
                  child: Center(child: Text('${r + 1}', style: labelStyle)),
                ),
                for (var c = 0; c < kBoardSize; c++)
                  _buildCell(r * kBoardSize + c, cs, preview),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int i, double cs, Set<int> preview) {
    final scheme = Theme.of(context).colorScheme;
    final ship = _fleet.shipAt(i);

    Color color = scheme.surfaceContainerHighest;
    if (ship != null) {
      color = ship == _lifted
          ? scheme.primary.withValues(alpha: 0.3)
          : scheme.primary;
    }
    if (preview.contains(i)) {
      color = _hoverValid
          ? Colors.green.withValues(alpha: 0.7)
          : Colors.red.withValues(alpha: 0.6);
    }

    final cell = Container(
      width: cs,
      height: cs,
      padding: const EdgeInsets.all(1),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    if (ship == null) return SizedBox(key: ValueKey('place-$i'), child: cell);

    final horizontal = _isHorizontal(ship);
    final grab = ship.cells.indexOf(i);
    return Draggable<_Drag>(
      key: ValueKey('place-$i'),
      data: _Drag(ship.length, horizontal, ship),
      feedback: _ShipShape(
          length: ship.length, horizontal: horizontal, cs: cs, floating: true),
      dragAnchorStrategy: (draggable, context, position) {
        final box = context.findRenderObject() as RenderBox;
        return _anchor(box.globalToLocal(position), grab, horizontal, cs);
      },
      onDragStarted: () => setState(() => _lifted = ship),
      onDragEnd: (_) => setState(() => _lifted = null),
      // Taxtadan tashqariga tashlandi — kema portga qaytadi
      onDraggableCanceled: (_, _) => setState(() => _fleet.ships.remove(ship)),
      child: GestureDetector(onTap: () => _rotate(ship), child: cell),
    );
  }

  Widget _buildPort(double cs) {
    final remaining = _fleet.remaining;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(remaining.isEmpty
                    ? 'Hamma kemalar joyida!'
                    : 'Port: ${remaining.length} ta kema'),
              ),
              TextButton.icon(
                onPressed: remaining.isEmpty
                    ? null
                    : () => setState(() => _horizontal = !_horizontal),
                icon: const Icon(Icons.rotate_90_degrees_ccw),
                label: Text(_horizontal ? 'Gorizontal' : 'Vertikal'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: cs * 0.4,
            runSpacing: cs * 0.3,
            children: [
              for (var k = 0; k < remaining.length; k++)
                _buildPortShip(k, remaining[k], cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortShip(int k, int length, double cs) {
    // Portda kemalar doim gorizontal chiziladi; qo'yiladigan yo'nalish — _horizontal
    final horizontal = _horizontal;
    return Draggable<_Drag>(
      key: ValueKey('port-$k'),
      data: _Drag(length, horizontal),
      feedback: _ShipShape(
          length: length, horizontal: horizontal, cs: cs, floating: true),
      childWhenDragging: Opacity(
          opacity: 0.3,
          child: _ShipShape(length: length, horizontal: true, cs: cs)),
      dragAnchorStrategy: (draggable, context, position) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(position);
        final grab = (local.dx ~/ cs).clamp(0, length - 1);
        final inCell = Offset(local.dx - grab * cs, local.dy);
        return _anchor(inCell, grab, horizontal, cs);
      },
      onDragEnd: (_) => _clearHover(),
      child: _ShipShape(length: length, horizontal: true, cs: cs),
    );
  }

  Widget _buildButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(_fleet.randomize),
                child: const Text('Tasodifiy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(_fleet.clear),
                child: const Text('Tozalash'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('ready'),
          onPressed: _fleet.complete ? widget.onReady : null,
          child: const Text('Tayyor'),
        ),
      ],
    );
  }
}

/// Kema tasviri: [length] ta katak.
class _ShipShape extends StatelessWidget {
  final int length;
  final bool horizontal;
  final double cs;
  final bool floating;

  const _ShipShape({
    required this.length,
    required this.horizontal,
    required this.cs,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cells = [
      for (var k = 0; k < length; k++)
        Container(
          width: cs,
          height: cs,
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: floating ? 0.85 : 1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
    ];
    return Material(
      color: Colors.transparent,
      child: horizontal
          ? Row(mainAxisSize: MainAxisSize.min, children: cells)
          : Column(mainAxisSize: MainAxisSize.min, children: cells),
    );
  }
}
