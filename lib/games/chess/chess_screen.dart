import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import '../../ui/kit.dart';
import 'chess_game.dart';
import 'chess_pieces.dart';

/// Sozlamalar: 2 kishi yoki kompyuterga qarshi.
Future<({bool vsAi, String humanColor, int level})?> showChessSetup(
    BuildContext context) {
  var vsAi = true;
  var color = 'w';
  var level = 2;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Shaxmat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Kompyuter')),
                ButtonSegment(value: false, label: Text('2 kishi')),
              ],
              selected: {vsAi},
              onSelectionChanged: (s) => setState(() => vsAi = s.first),
            ),
            if (vsAi) ...[
              const SizedBox(height: 16),
              const Text('Siz'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'w', label: Text('Oq')),
                  ButtonSegment(value: 'b', label: Text('Qora')),
                ],
                selected: {color},
                onSelectionChanged: (s) => setState(() => color = s.first),
              ),
              const SizedBox(height: 16),
              const Text('Daraja'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Oson')),
                  ButtonSegment(value: 2, label: Text("O'rta")),
                  ButtonSegment(value: 3, label: Text('Qiyin')),
                ],
                selected: {level},
                onSelectionChanged: (s) => setState(() => level = s.first),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, (vsAi: vsAi, humanColor: color, level: level)),
            child: const Text('Boshlash'),
          ),
        ],
      );
    }),
  );
}

class ChessScreen extends StatefulWidget {
  final bool vsAi;
  final String humanColor;
  final int level;

  /// Tayyor pozitsiya (test va ekran rasmlari uchun).
  final ChessGame? initialGame;

  const ChessScreen({
    super.key,
    this.vsAi = false,
    this.humanColor = 'w',
    this.level = 2,
    this.initialGame,
  });

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late ChessGame _game = widget.initialGame ?? ChessGame();
  int? _selected;
  bool _thinking = false;
  late bool _flipped = widget.vsAi && widget.humanColor == 'b';

  bool get _aiTurn => widget.vsAi && _game.turn != widget.humanColor;

  static const _levelNames = {1: 'Oson', 2: "O'rta", 3: 'Qiyin'};

  @override
  void initState() {
    super.initState();
    _maybeAi();
  }

  Future<void> _maybeAi() async {
    if (!_aiTurn || _game.result != ChessResult.playing) return;
    setState(() => _thinking = true);
    // "O'ylayapti" ko'rinsin, keyin hisoblaymiz
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final m = _game.bestMove(widget.level);
    if (m != null) _game.play(m);
    HapticFeedback.selectionClick();
    setState(() => _thinking = false);
  }

  Future<void> _tap(int sq) async {
    if (_thinking || _aiTurn || _game.result != ChessResult.playing) return;
    final piece = _game.board[sq];
    final mine = piece.isNotEmpty && (isWhitePiece(piece) == (_game.turn == 'w'));
    final sel = _selected;

    if (sel != null) {
      final options =
          _game.legalMoves().where((m) => m.from == sel && m.to == sq).toList();
      if (options.isNotEmpty) {
        var move = options.first;
        if (options.length > 1) {
          // Piyoda aylanishi — qaysi dona?
          final promo = await _askPromotion();
          if (promo == null) return;
          move = options.firstWhere((m) => m.promo == promo);
        }
        Telegram.haptic();
        HapticFeedback.selectionClick();
        setState(() {
          _game.play(move);
          _selected = null;
        });
        _maybeAi();
        return;
      }
    }
    setState(() => _selected = mine && sq != sel ? sq : null);
  }

  Future<String?> _askPromotion() {
    final white = _game.turn == 'w';
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Qaysi donaga aylansin?'),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final p in ['q', 'r', 'b', 'n'])
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(ctx, p),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChessPiece(piece: white ? p.toUpperCase() : p, size: 56),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_thinking) return;
    setState(() {
      _game.undo();
      // Kompyuterga qarshi — o'z yurishingizgacha qaytadi
      if (widget.vsAi && _aiTurn) _game.undo();
      _selected = null;
    });
  }

  void _restart() => setState(() {
        _game = ChessGame();
        _selected = null;
        _thinking = false;
        _maybeAi();
      });

  String _status() {
    final r = _game.result;
    final side = _game.turn == 'w' ? 'Oq' : 'Qora';
    final other = _game.turn == 'w' ? 'Qora' : 'Oq';
    return switch (r) {
      ChessResult.checkmate => 'Mat! $other yutdi',
      ChessResult.stalemate => 'Pat — durang',
      ChessResult.fiftyMoves => 'Durang (50 yurish qoidasi)',
      ChessResult.repetition => 'Durang (uch marta takrorlandi)',
      ChessResult.material => "Durang (matga dona yetmaydi)",
      ChessResult.playing => _thinking
          ? "Kompyuter o'ylayapti..."
          : '$side navbati${_game.inCheck() ? ' — SHAX!' : ''}',
    };
  }

  /// Material ustunligi (oq tomonidan).
  int _material() {
    const v = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9, 'k': 0};
    var s = 0;
    for (final p in _game.board) {
      if (p.isEmpty) continue;
      s += (isWhitePiece(p) ? 1 : -1) * v[p.toLowerCase()]!;
    }
    return s;
  }

  String _playerName(String color) {
    if (widget.vsAi && color != widget.humanColor) {
      return 'Kompyuter (${_levelNames[widget.level]})';
    }
    if (widget.vsAi) return 'Siz';
    return color == 'w' ? 'Oq' : 'Qora';
  }

  Widget _playerBar(String color) {
    final active = _game.turn == color && _game.result == ChessResult.playing;
    // Shu tomon urib olgan donalar — raqib donalari
    final captured = _game.capturedPieces(color == 'w' ? 'b' : 'w');
    final adv = _material() * (color == 'w' ? 1 : -1);
    final isAi = widget.vsAi && color != widget.humanColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: active ? const Color(0xFFE8C07A) : Colors.white12,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color == 'w' ? const Color(0xFFF1EDE6) : const Color(0xFF2E2E2E),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: isAi
                  ? const Icon(Icons.smart_toy_rounded, size: 22, color: Color(0xFFE8C07A))
                  : ChessPiece(piece: color == 'w' ? 'K' : 'k', size: 30),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_playerName(color),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
                SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      for (final p in captured)
                        Align(widthFactor: 0.62, child: ChessPiece(piece: p, size: 18)),
                      if (adv > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('+$adv',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (active && _thinking && isAi)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8C07A)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moves = _game.san;
    final top = _flipped ? 'w' : 'b';
    final bottom = _flipped ? 'b' : 'w';
    final result = _game.result;
    final check = _game.inCheck() && result == ChessResult.playing;

    return GameScaffold(
      title: 'Shaxmat',
      palette: GamePalette.chess,
      actions: [
        IconButton(
            tooltip: 'Yurishni qaytarish',
            icon: const Icon(Icons.undo_rounded),
            onPressed: _game.canUndo && !_thinking ? _undo : null),
        IconButton(
            tooltip: 'Taxtani aylantirish',
            icon: const Icon(Icons.screen_rotation_alt_rounded),
            onPressed: () => setState(() => _flipped = !_flipped)),
        IconButton(
            tooltip: 'Qaytadan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _restart),
      ],
      body: Stack(
        children: [
          LayoutBuilder(builder: (context, box) {
            final board = min(box.maxWidth - 12, box.maxHeight - 200);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _playerBar(top),
                const SizedBox(height: 8),
                SizedBox(width: board, height: board, child: _buildBoard()),
                const SizedBox(height: 8),
                _playerBar(bottom),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_status()),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: check
                          ? Colors.red.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Text(_status(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: check ? FontWeight.w900 : FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(height: 8),
                // Yurishlar tarixi
                SizedBox(
                  height: 26,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      Center(
                        child: Text(
                          [
                            for (var i = 0; i < moves.length; i += 2)
                              '${i ~/ 2 + 1}. ${moves[i]}${i + 1 < moves.length ? ' ${moves[i + 1]}' : ''}',
                          ].join('   '),
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          if (result != ChessResult.playing)
            Positioned.fill(
              child: WinOverlay(
                title: result == ChessResult.checkmate ? 'Mat!' : 'Durang',
                subtitle: _status(),
                confetti: result == ChessResult.checkmate,
                color: const Color(0xFFE8C07A),
                actions: [
                  GameButton(
                    label: "Yana o'ynash",
                    icon: Icons.replay_rounded,
                    colors: const [Color(0xFFE8C07A), Color(0xFFB07A3A)],
                    onPressed: _restart,
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
      ),
    );
  }

  Widget _buildBoard() {
    final g = _game;
    final targets = _selected == null
        ? const <int>{}
        : {
            for (final m in g.legalMoves())
              if (m.from == _selected) m.to,
          };
    final last = g.lastMove;
    final checkSq = g.inCheck() ? g.kingSquare(g.turn) : -1;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B4423), Color(0xFF3E2410), Color(0xFF5A3518)],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(builder: (context, box) {
          final s = box.maxWidth / 8;
          Offset pos(int sq) {
            final k = _flipped ? 63 - sq : sq;
            return Offset((k % 8) * s, (k ~/ 8) * s);
          }

          final squares = <Widget>[];
          for (var sq = 0; sq < 64; sq++) {
            final r = sq ~/ 8, c = sq % 8;
            final light = (r + c).isEven;
            var bg = light ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);
            if (last != null && (sq == last.from || sq == last.to)) {
              bg = Color.lerp(bg, const Color(0xFFF7EC5E), 0.55)!;
            }
            if (sq == _selected) bg = Color.lerp(bg, const Color(0xFF7FC97F), 0.7)!;
            final p = pos(sq);
            final k = _flipped ? 63 - sq : sq;
            final coord = TextStyle(
                fontSize: s * 0.2,
                fontWeight: FontWeight.w800,
                color: light ? const Color(0xFFB58863) : const Color(0xFFF0D9B5));
            squares.add(Positioned(
              left: p.dx,
              top: p.dy,
              width: s,
              height: s,
              child: GestureDetector(
                key: ValueKey('sq-${squareName(sq)}'),
                onTap: () => _tap(sq),
                child: Container(
                  color: bg,
                  child: Stack(children: [
                    if (k % 8 == 0)
                      Positioned(left: 2, top: 1, child: Text('${8 - r}', style: coord)),
                    if (k >= 56)
                      Positioned(right: 2, bottom: 0, child: Text('abcdefgh'[c], style: coord)),
                    if (sq == checkSq)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(colors: [
                              Colors.red.withValues(alpha: 0.95),
                              Colors.red.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                    if (targets.contains(sq))
                      Center(
                        child: g.board[sq].isEmpty
                            ? Container(
                                width: s * 0.3,
                                height: s * 0.3,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle, color: Color(0x55000000)),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0x55000000), width: s * 0.08),
                                ),
                              ),
                      ),
                  ]),
                ),
              ),
            ));
          }

          final pieces = <Widget>[];
          for (var sq = 0; sq < 64; sq++) {
            final piece = g.board[sq];
            if (piece.isEmpty) continue;
            final to = pos(sq);
            final moved = last != null && last.to == sq;
            final child = IgnorePointer(
              child: AnimatedScale(
                scale: sq == _selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 120),
                child: ChessPiece(piece: piece, size: s),
              ),
            );
            if (moved) {
              // Oxirgi yurgan dona joyiga siljib boradi
              final from = pos(last.from);
              pieces.add(TweenAnimationBuilder<Offset>(
                key: ValueKey('move-${g.san.length}'),
                tween: Tween(begin: from, end: to),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, o, child) => Positioned(
                    left: o.dx, top: o.dy, width: s, height: s, child: child!),
                child: child,
              ));
            } else {
              pieces.add(Positioned(left: to.dx, top: to.dy, width: s, height: s, child: child));
            }
          }

          return Stack(children: [...squares, ...pieces]);
        }),
      ),
    );
  }
}
