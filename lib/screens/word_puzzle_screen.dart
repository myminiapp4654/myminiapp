import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oyinim_core/oyinim_core.dart';
import '../net/server_client.dart';
import '../services/word_puzzle_service.dart';
import '../services/stars_service.dart';
import '../services/audio_service.dart';

// ── Retro 8-bit color palette ─────────────────────────────
const _bg = Color(0xFF0D0D0D);
const _panel = Color(0xFF1A1A2A);
const _border = Color(0xFF3A3A5A);
const _accent = Color(0xFF00FF88);
const _accentDim = Color(0xFF007744);
const _warn = Color(0xFFFFCC00);
const _danger = Color(0xFFFF2244);
const _white = Color(0xFFE0E0E0);
const _dim = Color(0xFF555577);

const _tileColors = [
  Color(0xFF0066CC),
  Color(0xFF8800CC),
  Color(0xFFCC4400),
  Color(0xFF006644),
  Color(0xFFCC0066),
  Color(0xFF004488),
  Color(0xFF884400),
  Color(0xFF006600),
];

class WordPuzzleScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const WordPuzzleScreen(
      {super.key, required this.roomCode, required this.isHost});

  @override
  State<WordPuzzleScreen> createState() => _WordPuzzleScreenState();
}

class _WordPuzzleScreenState extends State<WordPuzzleScreen>
    with TickerProviderStateMixin {
  final _service = WordPuzzleService();
  final _starsService = StarsService();
  bool _revealingWithStar = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _winCtrl;
  late Animation<double> _winAnim;

  List<String> _prevWrong = [];

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));

    _winCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _winAnim = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _winCtrl.dispose();
    super.dispose();
  }

  Future<void> _useStarReveal() async {
    if (_revealingWithStar) return;
    setState(() => _revealingWithStar = true);
    try {
      final spent = await _service.revealWithStar(widget.roomCode);
      if (!spent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Yulduzlar yetarli emas!'),
          backgroundColor: _danger,
          duration: Duration(seconds: 2),
        ));
      }
    } on ServerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _revealingWithStar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.gameStream(widget.roomCode),
      builder: (ctx, snap) {
        if (!snap.hasData) return _loadingScaffold();
        if (!snap.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return _loadingScaffold();
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String;
        final result = data['result'] as String?;
        final revealed = List<String>.from(data['revealedLetters']);
        final wrong = List<String>.from(data['wrongLetters']);
        final tiles = List<String>.from(data['letterTiles']);
        final puzzle = data['puzzle'] as Map<String, dynamic>;
        final words = (puzzle['words'] as List)
            .map((w) => w as Map<String, dynamic>)
            .toList();
        final p1 = data['player1'] as Map<String, dynamic>;
        final p2 = data['player2'] as Map<String, dynamic>?;
        final currentTurn = data['currentTurn'] as String;
        final level = (data['level'] as int?) ?? 0;
        final isMyTurn =
            currentTurn == _service.myUid && status == 'playing';

        if (wrong.length > _prevWrong.length &&
            (_shakeCtrl.isCompleted || !_shakeCtrl.isAnimating)) {
          _shakeCtrl.forward(from: 0);
          HapticFeedback.mediumImpact();
          AudioService.instance.playSfx('wrong');
        }
        _prevWrong = List.from(wrong);

        if (result == 'win' &&
            !_winCtrl.isAnimating &&
            !_winCtrl.isCompleted) {
          _winCtrl.forward();
          AudioService.instance.playSfx('win');
        }

        if (status == 'waiting') return _buildWaiting(data);

        return Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(level, revealed, wrong, status),
          body: status == 'finished'
              ? _buildFinished(result, words, revealed, p1, p2, level)
              : _buildGame(
                  words, tiles, revealed, wrong, isMyTurn, p1, p2, currentTurn),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      int level, List<String> revealed, List<String> wrong, String status) {
    return AppBar(
      backgroundColor: _panel,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _accent),
        onPressed: () async {
          final nav = Navigator.of(context);
          if (widget.isHost && status != 'finished') {
            await _service.deleteRoom(widget.roomCode);
          }
          nav.pop();
        },
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pixelText('SO\'Z TOPISH', _accent, 13),
          _pixelText('DARAJA ${level + 1}', _dim, 10),
        ],
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 2, color: _accent.withValues(alpha: 0.4)),
      ),
      actions: [
        // Star button
        StreamBuilder<int>(
          stream: _starsService.starsStream(),
          builder: (_, snap) {
            final stars = snap.data ?? 0;
            final canUse = status == 'playing' && !_revealingWithStar;
            return GestureDetector(
              onTap: canUse ? _useStarReveal : null,
              child: _pixelContainer(
                margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
                color: stars > 0 ? _warn.withValues(alpha: 0.15) : _panel,
                borderColor: stars > 0 ? _warn : _border,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _revealingWithStar
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _warn),
                          )
                        : _pixelText('★', _warn, 13),
                    const SizedBox(width: 3),
                    _pixelText('$stars', stars > 0 ? _warn : _dim, 12),
                  ],
                ),
              ),
            );
          },
        ),
        // Lives
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: List.generate(5, (i) {
              final alive = i < (5 - wrong.length);
              return _pixelText(alive ? '♥' : '♡',
                  alive ? _danger : _dim, 14);
            }),
          ),
        ),
      ],
    );
  }

  Widget _loadingScaffold() => const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );

  Widget _buildWaiting(Map<String, dynamic> data) {
    final p1 = data['player1'] as Map<String, dynamic>;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _accent),
          onPressed: () async {
            final nav = Navigator.of(context);
            await _service.deleteRoom(widget.roomCode);
            nav.pop();
          },
        ),
        title: _pixelText('SO\'Z TOPISH', _accent, 14),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 2, color: _accent.withValues(alpha: 0.4)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pixelText('[ SO\'Z TOPISH ]', _accent, 22),
              const SizedBox(height: 24),
              _pixelText(p1['name'] as String, _white, 16),
              const SizedBox(height: 8),
              _pixelText('IKKINCHI O\'YINCHI KUTILMOQDA...', _dim, 11),
              const SizedBox(height: 32),
              _pixelContainer(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 20),
                color: _panel,
                borderColor: _accent,
                child: Column(
                  children: [
                    _pixelText('XONA KODI', _dim, 11),
                    const SizedBox(height: 8),
                    _pixelText(widget.roomCode, _accent, 28),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kod nusxalandi!')));
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy, color: _accent, size: 12),
                          const SizedBox(width: 4),
                          _pixelText('NUSXALASH', _accent, 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame(
    List<Map<String, dynamic>> words,
    List<String> tiles,
    List<String> revealed,
    List<String> wrong,
    bool isMyTurn,
    Map p1,
    Map? p2,
    String currentTurn,
  ) {
    final turnName = currentTurn == (p1['uid'] as String)
        ? p1['name'] as String
        : (p2?['name'] as String? ?? '...');
    final isMe = currentTurn == _service.myUid;

    return Column(
      children: [
        // Turn banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7),
          color: isMe
              ? _accent.withValues(alpha: 0.12)
              : _panel,
          child: _pixelText(
            isMe ? '[ SENING NAVBATING ]' : '[ $turnName TANLAYAPTI... ]',
            isMe ? _accent : _dim,
            11,
          ),
        ),

        // Words area
        Expanded(
          flex: 5,
          child: AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: words.map((w) => _buildWordRow(w, revealed)).toList(),
              ),
            ),
          ),
        ),

        // Wrong letters bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: _panel,
          child: Row(
            children: [
              _pixelText('NOTO\'G\'RI: ', _dim, 10),
              ...wrong.map((l) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _pixelText(l, _danger, 12),
                  )),
              if (wrong.isEmpty) _pixelText('—', _dim, 10),
            ],
          ),
        ),

        // Tile grid
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: _buildTileGrid(tiles, revealed, wrong, isMyTurn),
          ),
        ),
      ],
    );
  }

  Widget _buildWordRow(Map<String, dynamic> word, List<String> revealed) {
    final w = word['word'] as String;
    final hint = word['hint'] as String;
    final emoji = word['emoji'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            _pixelText(hint, _dim, 10),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: w.split('').map((letter) {
            final isRevealed = revealed.contains(letter);
            return _PixelLetterCell(letter: letter, isRevealed: isRevealed);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTileGrid(List<String> tiles, List<String> revealed,
      List<String> wrong, bool isMyTurn) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final letter = tiles[i];
        final isCorrect = revealed.contains(letter);
        final isWrong = wrong.contains(letter);
        final isUsed = isCorrect || isWrong;
        final canTap = isMyTurn && !isUsed;
        final tileColor = _tileColors[i % _tileColors.length];

        return GestureDetector(
          onTap: canTap
              ? () => _service.pickLetter(widget.roomCode, letter)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isWrong
                  ? _danger.withValues(alpha: 0.2)
                  : isCorrect
                      ? _accent.withValues(alpha: 0.15)
                      : canTap
                          ? tileColor.withValues(alpha: 0.85)
                          : _panel,
              border: Border.all(
                color: isWrong
                    ? _danger
                    : isCorrect
                        ? _accent
                        : canTap
                            ? tileColor
                            : _border,
                width: 2,
              ),
              borderRadius: BorderRadius.zero, // pixel style — no rounding
              boxShadow: canTap
                  ? [
                      BoxShadow(
                          color: tileColor.withValues(alpha: 0.5),
                          blurRadius: 0,
                          offset: const Offset(2, 2))
                    ]
                  : null,
            ),
            child: Center(
              child: isWrong
                  ? _pixelText(letter, _danger, 16,
                      decoration: TextDecoration.lineThrough)
                  : isCorrect
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pixelText(letter, _accent, 14),
                            _pixelText('✓', _accent, 8),
                          ],
                        )
                      : _pixelText(letter,
                          canTap ? _white : _dim, 18),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinished(String? result, List<Map<String, dynamic>> words,
      List<String> revealed, Map p1, Map? p2, int level) {
    final isWin = result == 'win';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _panel,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: _pixelText('SO\'Z TOPISH', _accent, 14),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 2, color: _accent.withValues(alpha: 0.4)),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale:
                    isWin ? _winAnim : const AlwaysStoppedAnimation(1),
                child: _pixelText(isWin ? 'YUTDINGIZ!' : 'YUTQAZDINGIZ...',
                    isWin ? _accent : _danger, 24),
              ),
              const SizedBox(height: 8),
              _pixelText(
                  isWin ? '[ BARAKALLA! ]' : '[ KEYINROQ URINIB KORING ]',
                  isWin ? _accentDim : _dim,
                  12),
              const SizedBox(height: 24),
              ...words.map((w) {
                final word = w['word'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(w['emoji'] as String,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          _pixelText(w['hint'] as String, _dim, 10),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: word.split('').map((l) {
                          return _PixelLetterCell(
                              letter: l, isRevealed: true);
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              if (isWin && widget.isHost && level + 1 < kWordPuzzles.length)
                _pixelButton(
                  label: 'KEYINGI DARAJA (${level + 2}) ►',
                  color: _accent,
                  textColor: _bg,
                  onTap: () =>
                      _service.nextLevel(widget.roomCode, level + 1),
                ),
              if (isWin && !widget.isHost)
                _pixelContainer(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: _panel,
                  borderColor: _border,
                  child: _pixelText(
                      '⏳ XO\'JAYIN KEYINGI DARAJANI BOSHLAYDI',
                      _dim, 11),
                ),
              const SizedBox(height: 10),
              _pixelButton(
                label: '◄ XONAGA QAYTISH',
                color: _panel,
                textColor: _white,
                borderColor: _border,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pixel helpers ──────────────────────────────────────────

  static Widget _pixelText(String text, Color color, double size,
      {TextDecoration? decoration}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        decoration: decoration,
        decorationColor: color,
        fontFamily: 'monospace',
      ),
    );
  }

  static Widget _pixelContainer({
    required Widget child,
    Color color = _panel,
    Color borderColor = _border,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );
  }

  static Widget _pixelButton({
    required String label,
    required Color color,
    required Color textColor,
    Color borderColor = _accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
                color: borderColor.withValues(alpha: 0.5),
                blurRadius: 0,
                offset: const Offset(3, 3)),
          ],
        ),
        child: _pixelText(label, textColor, 13),
      ),
    );
  }
}

// ── Pixel Letter Cell ──────────────────────────────────────

class _PixelLetterCell extends StatelessWidget {
  final String letter;
  final bool isRevealed;

  const _PixelLetterCell({required this.letter, required this.isRevealed});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: isRevealed
          ? _RevealedPixelCell(key: ValueKey('r_$letter'), letter: letter)
          : const _HiddenPixelCell(key: ValueKey('hidden')),
    );
  }
}

class _RevealedPixelCell extends StatelessWidget {
  final String letter;
  const _RevealedPixelCell({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _accentDim,
        border: Border.all(color: _accent, width: 2),
        borderRadius: BorderRadius.zero,
        boxShadow: const [
          BoxShadow(color: _accent, blurRadius: 0, offset: Offset(2, 2)),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: _white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _HiddenPixelCell extends StatelessWidget {
  const _HiddenPixelCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border, width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: const Center(
        child: Text(
          '_',
          style: TextStyle(
            color: _dim,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}