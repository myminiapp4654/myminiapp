import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../telegram/telegram.dart';
import 'chess_game.dart';

const _glyphs = {
  'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
};

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

  const ChessScreen(
      {super.key, this.vsAi = false, this.humanColor = 'w', this.level = 2});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  var _game = ChessGame();
  int? _selected;
  bool _thinking = false;
  late bool _flipped = widget.vsAi && widget.humanColor == 'b';

  bool get _aiTurn => widget.vsAi && _game.turn != widget.humanColor;

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
                IconButton(
                  iconSize: 44,
                  onPressed: () => Navigator.pop(ctx, p),
                  icon: _PieceGlyph(piece: white ? p.toUpperCase() : p, size: 40),
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final moves = _game.san;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shaxmat'),
        actions: [
          IconButton(
              tooltip: 'Yurishni qaytarish',
              icon: const Icon(Icons.undo),
              onPressed: _game.canUndo && !_thinking ? _undo : null),
          IconButton(
              tooltip: 'Taxtani aylantirish',
              icon: const Icon(Icons.screen_rotation_alt),
              onPressed: () => setState(() => _flipped = !_flipped)),
          IconButton(
              tooltip: 'Qaytadan',
              icon: const Icon(Icons.refresh),
              onPressed: _restart),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Captured(pieces: _game.capturedPieces(_flipped ? 'b' : 'w')),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
                ),
              ),
            ),
            _Captured(pieces: _game.capturedPieces(_flipped ? 'w' : 'b')),
            const SizedBox(height: 4),
            Text(_status(), style: text.titleMedium),
            const SizedBox(height: 6),
            // Yurishlar tarixi
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Text([
                    for (var i = 0; i < moves.length; i += 2)
                      '${i ~/ 2 + 1}. ${moves[i]}${i + 1 < moves.length ? ' ${moves[i + 1]}' : ''}',
                  ].join('   ')),
                ],
              ),
            ),
            if (_game.result != ChessResult.playing)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton(
                    onPressed: _restart, child: const Text("Yana o'ynash")),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    final g = _game;
    final scheme = Theme.of(context).colorScheme;
    final targets = _selected == null
        ? const <int>{}
        : {
            for (final m in g.legalMoves())
              if (m.from == _selected) m.to,
          };
    final last = g.lastMove;
    final checkSq = g.inCheck() ? g.kingSquare(g.turn) : -1;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: 64,
      itemBuilder: (context, k) {
        final sq = _flipped ? 63 - k : k;
        final r = sq ~/ 8, c = sq % 8;
        final light = (r + c).isEven;
        Color bg = light ? const Color(0xFFEEDDBB) : const Color(0xFFB58863);
        if (last != null && (sq == last.from || sq == last.to)) {
          bg = Color.lerp(bg, Colors.yellow, 0.4)!;
        }
        if (sq == _selected) bg = scheme.primary.withValues(alpha: 0.7);
        if (sq == checkSq) bg = Colors.red.shade400;

        final piece = g.board[sq];
        final isTarget = targets.contains(sq);
        final coordStyle = TextStyle(
            fontSize: 9,
            color: light ? const Color(0xFFB58863) : const Color(0xFFEEDDBB));

        return GestureDetector(
          key: ValueKey('sq-${squareName(sq)}'),
          onTap: () => _tap(sq),
          child: Container(
            color: bg,
            child: Stack(
              children: [
                if (k % 8 == 0)
                  Positioned(left: 2, top: 1, child: Text('${8 - r}', style: coordStyle)),
                if (k >= 56)
                  Positioned(
                      right: 2,
                      bottom: 0,
                      child: Text('abcdefgh'[c], style: coordStyle)),
                if (piece.isNotEmpty)
                  Center(
                    child: LayoutBuilder(
                      builder: (context, box) =>
                          _PieceGlyph(piece: piece, size: box.maxWidth * 0.8),
                    ),
                  ),
                if (isTarget)
                  Center(
                    child: Container(
                      width: piece.isEmpty ? 14 : null,
                      height: piece.isEmpty ? 14 : null,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: piece.isEmpty ? Colors.black26 : null,
                        border: piece.isEmpty
                            ? null
                            : Border.all(color: Colors.black38, width: 4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PieceGlyph extends StatelessWidget {
  final String piece;
  final double size;

  const _PieceGlyph({required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    final white = isWhitePiece(piece);
    final glyph = _glyphs[piece.toLowerCase()]!;
    // Bitta to'ldirilgan belgi: oq donaga oq rang + qora chiziq
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(glyph,
            style: TextStyle(
              fontSize: size,
              height: 1,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = size * 0.06
                ..color = white ? Colors.black : Colors.white54,
            )),
        Text(glyph,
            style: TextStyle(
              fontSize: size,
              height: 1,
              color: white ? Colors.white : Colors.black,
            )),
      ],
    );
  }
}

class _Captured extends StatelessWidget {
  final List<String> pieces;
  const _Captured({required this.pieces});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final p in pieces) _PieceGlyph(piece: p, size: 18),
        ],
      ),
    );
  }
}
