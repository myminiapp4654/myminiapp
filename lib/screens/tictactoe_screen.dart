import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../net/server_client.dart';
import '../services/game_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';

class TicTacToeScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;

  const TicTacToeScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
  });

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  late AnimationController _scoreAnimX;
  late AnimationController _scoreAnimO;
  int _prevScoreX = 0;
  int _prevScoreO = 0;
  String _prevStatus = '';

  @override
  void initState() {
    super.initState();
    _scoreAnimX = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scoreAnimO = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _scoreAnimX.dispose();
    _scoreAnimO.dispose();
    super.dispose();
  }

  Future<void> _makeMove(int index) async {
    await _gameService.makeMove(widget.roomCode, index);
  }

  void _leaveGame(Map<String, dynamic> data) async {
    if (data['status'] != 'finished' && widget.isCreator) {
      await _gameService.deleteRoom(widget.roomCode);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _gameService.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return pixelLoading();

        if (!snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pixelText('[ XONA O\'CHIRILDI ]', kDanger, 18),
                  const SizedBox(height: 20),
                  pixelButton(
                    label: '◄ ORQAGA',
                    onTap: () => Navigator.pop(context),
                    color: kBg,
                    textColor: kAccent,
                    borderColor: kAccent,
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final board = List<String>.from(data['board']);
        final status = data['status'] as String;
        final currentTurn = data['currentTurn'] as String;
        final player1 = data['player1'] as Map<String, dynamic>;
        final player2 = data['player2'] as Map<String, dynamic>?;
        final winner = data['winner'] as String?;
        final gridSize = (data['gridSize'] as int?) ?? 10;
        final scoreX = (data['scoreX'] as int?) ?? 0;
        final scoreO = (data['scoreO'] as int?) ?? 0;
        final winningCells = Set<int>.from(
            (data['winningCells'] as List? ?? []).map((e) => e as int));

        if (scoreX != _prevScoreX) {
          _prevScoreX = scoreX;
          _scoreAnimX.forward(from: 0);
          AudioService.instance.playSfx('score');
        }
        if (scoreO != _prevScoreO) {
          _prevScoreO = scoreO;
          _scoreAnimO.forward(from: 0);
          AudioService.instance.playSfx('score');
        }
        if (status == 'finished' && _prevStatus != 'finished') {
          _prevStatus = status;
          AudioService.instance.playSfx('win');
        } else if (status != _prevStatus) {
          _prevStatus = status;
        }

        final mySymbol = _gameService.myUid == player1['uid'] ? 'X' : 'O';
        final isMyTurn = currentTurn == mySymbol && status == 'playing';
        final filledCount = board.where((c) => c.isNotEmpty).length;
        final totalCells = gridSize * gridSize;
        final progress = filledCount / totalCells;

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kPanel,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kAccent),
              onPressed: () => _leaveGame(data),
            ),
            title: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod nusxalandi!')));
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pixelText('X-O  $gridSize×$gridSize  ', kAccent, 13),
                  pixelText(widget.roomCode, kWarn, 13),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, color: kDim, size: 12),
                ],
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    children: [
                      _buildScoreRow(player1, player2, scoreX, scoreO,
                          currentTurn, status, mySymbol),
                      const SizedBox(height: 8),
                      _buildProgressBar(progress, filledCount, totalCells),
                      const SizedBox(height: 8),
                      _buildStatusBar(status, winner, isMyTurn, mySymbol,
                          player1, player2, scoreX, scoreO),
                      const SizedBox(height: 8),
                      Expanded(
                        child: status == 'waiting'
                            ? _buildWaitingView()
                            : _buildBoard(board, winningCells, gridSize,
                                isMyTurn, mySymbol),
                      ),
                      if (status == 'finished') ...[
                        const SizedBox(height: 8),
                        _buildResultCard(winner, mySymbol, scoreX, scoreO,
                            player1, player2),
                        const SizedBox(height: 8),
                        pixelButton(
                          label: '◄ XONAGA QAYTISH',
                          onTap: () => Navigator.pop(context),
                          color: kBg,
                          textColor: kAccent,
                          borderColor: kAccent,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreRow(Map<String, dynamic> player1, Map<String, dynamic>? player2,
      int scoreX, int scoreO, String currentTurn, String status, String mySymbol) {
    final activeX = currentTurn == 'X' && status == 'playing';
    final activeO = currentTurn == 'O' && status == 'playing';

    return Row(
      children: [
        Expanded(
          child: _scoreCard(
            name: player1['name'] as String? ?? '?',
            symbol: 'X',
            score: scoreX,
            isActive: activeX,
            isMe: mySymbol == 'X',
            anim: _scoreAnimX,
            color: kBlue,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: pixelText('VS', kDim, 13),
        ),
        Expanded(
          child: _scoreCard(
            name: player2?['name'] as String? ?? '...',
            symbol: 'O',
            score: scoreO,
            isActive: activeO,
            isMe: mySymbol == 'O',
            anim: _scoreAnimO,
            color: kWarn,
          ),
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String name,
    required String symbol,
    required int score,
    required bool isActive,
    required bool isMe,
    required AnimationController anim,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.12) : kPanel,
        border: Border.all(
          color: isActive ? color : kBorder,
          width: 2,
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 0, offset: const Offset(3, 3))]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              pixelText(symbol, color, 18),
              if (isActive) ...[
                const SizedBox(width: 4),
                Container(width: 6, height: 6, color: color),
              ],
            ],
          ),
          const SizedBox(height: 2),
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.4).animate(
              CurvedAnimation(parent: anim, curve: Curves.elasticOut),
            ),
            child: pixelText('$score', color, 26),
          ),
          const SizedBox(height: 2),
          pixelText(isMe ? '${name.toUpperCase()} *' : name.toUpperCase(), kDim, 9),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, int filled, int total) {
    final barColor = progress < 0.5 ? kAccent : progress < 0.8 ? kWarn : kDanger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            pixelText('TAXTA', kDim, 9, align: TextAlign.left),
            pixelText('$filled / $total', kDim, 9),
          ],
        ),
        const SizedBox(height: 3),
        Stack(
          children: [
            Container(height: 6, color: kBorder),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              width: (MediaQuery.of(context).size.width - 20) * progress,
              color: barColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBar(String status, String? winner, bool isMyTurn,
      String mySymbol, Map player1, Map? player2, int scoreX, int scoreO) {
    String text;
    Color color;

    if (status == 'waiting') {
      text = "DO'STINGIZ KUTILMOQDA...";
      color = kDim;
    } else if (status == 'finished') {
      if (winner == 'draw') {
        text = 'DURANG!  X:$scoreX — O:$scoreO';
        color = kWarn;
      } else {
        final iWon = winner == mySymbol;
        text = iWon ? 'SIZ YUTDINGIZ!' : 'YUTQAZDINGIZ...';
        color = iWon ? kAccent : kDanger;
      }
    } else {
      text = isMyTurn ? '[ SIZNING NAVBATINGIZ - $mySymbol ]' : '[ RAQIB O\'YLAYAPTI... ]';
      color = isMyTurn ? kAccent : kDim;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        borderRadius: BorderRadius.zero,
      ),
      child: pixelText(text, color, 11),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          pixelText('[ KUTILMOQDA ]', kAccent, 20),
          const SizedBox(height: 16),
          pixelText("IKKINCHI O'YINCHI KUTING...", kDim, 11),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod nusxalandi!')));
            },
            child: pixelContainer(
              borderColor: kAccent,
              color: kAccentDim.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, color: kAccent, size: 16),
                  const SizedBox(width: 8),
                  pixelText(widget.roomCode, kAccent, 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(List<String> board, Set<int> winningCells, int gridSize,
      bool isMyTurn, String mySymbol) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
      final spacing = gridSize <= 10 ? 2.0 : 1.5;

      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 3.0,
        child: SizedBox(
          width: size,
          height: size,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridSize,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: gridSize * gridSize,
            itemBuilder: (context, index) {
              final value = board[index];
              final canTap = value.isEmpty && isMyTurn;
              final isWinning = winningCells.contains(index);
              final cellColor = value == 'X' ? kBlue : kWarn;
              final cellSize = (size - spacing * (gridSize - 1)) / gridSize;

              return GestureDetector(
                onTap: canTap ? () => _makeMove(index) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: isWinning
                        ? cellColor.withValues(alpha: 0.25)
                        : canTap
                            ? kPanel
                            : kBg,
                    border: Border.all(
                      color: isWinning
                          ? cellColor
                          : canTap
                              ? kBorder
                              : kBg,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Center(
                    child: value.isNotEmpty
                        ? Text(
                            value,
                            style: TextStyle(
                              fontSize: cellSize * 0.45,
                              fontWeight: FontWeight.w900,
                              color: isWinning
                                  ? cellColor
                                  : cellColor.withValues(alpha: 0.8),
                              fontFamily: 'monospace',
                            ),
                          )
                        : canTap
                            ? Container(
                                width: cellSize * 0.15,
                                height: cellSize * 0.15,
                                color: kBorder,
                              )
                            : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildResultCard(String? winner, String mySymbol, int scoreX,
      int scoreO, Map player1, Map? player2) {
    final iWon = winner == mySymbol;
    final isDraw = winner == 'draw';
    final color = isDraw ? kWarn : iWon ? kAccent : kDanger;

    return pixelContainer(
      borderColor: color,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          pixelText(
            isDraw ? 'DURANG!' : iWon ? 'SIZ YUTDINGIZ!' : "MAG'LUB",
            color, 18,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _resultScore(player1['name'] as String? ?? '?', 'X', scoreX,
                  kBlue, winner == 'X'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: pixelText('—', kDim, 18),
              ),
              _resultScore(player2?['name'] as String? ?? '?', 'O', scoreO,
                  kWarn, winner == 'O'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultScore(
      String name, String symbol, int score, Color color, bool isWinner) {
    return Column(
      children: [
        pixelText(isWinner ? '★' : ' ', color, 16),
        pixelText(symbol, color, 18),
        pixelText('$score', color, 28),
        pixelText(name.toUpperCase(), kDim, 9),
      ],
    );
  }
}
