import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/checkers_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';

class CheckersScreen extends StatefulWidget {
  final String roomCode;
  final bool isCreator;

  const CheckersScreen({
    super.key,
    required this.roomCode,
    required this.isCreator,
  });

  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  final _service = CheckersService();
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  int? _selectedCell;
  List<Map<String, int>> _validMoves = [];
  String _prevStatus = '';

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCellTap(int index, List<String> board, String myColor,
      bool isMyTurn, int chainJump) {
    if (!isMyTurn) return;

    final move = _validMoves.firstWhere(
      (m) => m['to'] == index,
      orElse: () => {},
    );
    if (move.isNotEmpty && _selectedCell != null) {
      _service.makeMove(widget.roomCode, _selectedCell!, move);
      AudioService.instance.playSfx('move');
      setState(() {
        _selectedCell = null;
        _validMoves = [];
      });
      return;
    }

    if (chainJump >= 0) return;

    final piece = board[index];
    if (piece.isNotEmpty && piece.toLowerCase() == myColor) {
      final moves = _service.validMoves(board, index, chainJump);
      setState(() {
        _selectedCell = index;
        _validMoves = moves;
      });
    } else {
      setState(() {
        _selectedCell = null;
        _validMoves = [];
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await _service.sendMessage(widget.roomCode, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return pixelLoading();

        if (!snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pixelText("[ XONA O'CHIRILDI ]", kDanger, 18),
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
        final chainJump = (data['chainJump'] as int?) ?? -1;
        final lastMoveRaw = data['lastMove'] as Map<String, dynamic>?;
        final lastMoveFrom = lastMoveRaw?['from'] as int?;
        final lastMoveTo = lastMoveRaw?['to'] as int?;

        if (status == 'finished' && _prevStatus != 'finished') {
          _prevStatus = status;
          AudioService.instance.playSfx('win');
        } else if (status != _prevStatus) {
          _prevStatus = status;
        }

        final myColor = _service.myUid == player1['uid'] ? 'w' : 'b';
        final isMyTurn = currentTurn == myColor && status == 'playing';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (chainJump >= 0 && isMyTurn) {
            final moves = _service.validMoves(board, chainJump, chainJump);
            if (_selectedCell != chainJump || _validMoves != moves) {
              setState(() {
                _selectedCell = chainJump;
                _validMoves = moves;
              });
            }
          } else if (chainJump < 0 &&
              (_selectedCell != null || _validMoves.isNotEmpty)) {
            setState(() {
              _selectedCell = null;
              _validMoves = [];
            });
          }
        });

        final validMoveTos = _validMoves.map((m) => m['to']!).toList();

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kPanel,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kAccent),
              onPressed: () async {
                final nav = Navigator.of(context);
                if (status != 'finished' && widget.isCreator) {
                  await _service.deleteRoom(widget.roomCode);
                }
                nav.pop();
              },
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
                  pixelText('SHASHKA  ', kAccent, 13),
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
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    children: [
                      _playerCard(
                        name: player1['name'] as String,
                        color: 'w',
                        isActive: currentTurn == 'w' && status == 'playing',
                        isMe: myColor == 'w',
                        board: board,
                      ),
                      Expanded(
                        child: Center(
                          child: pixelText(
                            _statusText(status, winner, isMyTurn, myColor),
                            _statusColor(status, winner, myColor),
                            11,
                          ),
                        ),
                      ),
                      _playerCard(
                        name: player2?['name'] as String? ?? '...',
                        color: 'b',
                        isActive: currentTurn == 'b' && status == 'playing',
                        isMe: myColor == 'b',
                        board: board,
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                        ),
                        itemCount: 64,
                        itemBuilder: (context, index) => _buildCell(
                          index, board, myColor, isMyTurn, chainJump,
                          validMoveTos, lastMoveFrom, lastMoveTo,
                        ),
                      ),
                    ),
                  ),
                ),

                if (status == 'finished')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: pixelButton(
                      label: '◄ XONAGA QAYTISH',
                      onTap: () => Navigator.pop(context),
                      color: kBg,
                      textColor: kAccent,
                      borderColor: kAccent,
                    ),
                  ),

                _buildChat(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int index, List<String> board, String myColor,
      bool isMyTurn, int chainJump, List<int> validMoveTos,
      int? lastMoveFrom, int? lastMoveTo) {
    final row = index ~/ 8, col = index % 8;
    final isDark = (row + col) % 2 == 1;
    final piece = board[index];
    final isSelected = _selectedCell == index;
    final isValidTarget = validMoveTos.contains(index);
    final isLastFrom = lastMoveFrom == index;
    final isLastTo = lastMoveTo == index;

    Color bg;
    if (isSelected) {
      bg = kAccent.withValues(alpha: 0.45);
    } else if (isValidTarget) {
      bg = kAccentDim.withValues(alpha: 0.6);
    } else if (isLastTo) {
      bg = kWarn.withValues(alpha: 0.35);
    } else if (isLastFrom) {
      bg = kWarn.withValues(alpha: 0.15);
    } else if (isDark) {
      bg = const Color(0xFF1E1E2E);
    } else {
      bg = const Color(0xFF2E2E3E);
    }

    return GestureDetector(
      onTap: isDark
          ? () => _onCellTap(index, board, myColor, isMyTurn, chainJump)
          : null,
      child: Container(
        color: bg,
        child: Stack(
          children: [
            if (isValidTarget && piece.isEmpty)
              Center(
                child: Container(width: 8, height: 8, color: kAccent),
              ),
            if (piece.isNotEmpty)
              Center(child: _buildPiece(piece, isSelected)),
          ],
        ),
      ),
    );
  }

  Widget _buildPiece(String piece, bool isSelected) {
    final isWhite = piece == 'w' || piece == 'W';
    final isKing = piece == 'W' || piece == 'B';
    final color = isWhite ? kWhite : kBg;
    final borderColor = isSelected ? kAccent : isWhite ? kDim : kBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: EdgeInsets.all(isSelected ? 3 : 5),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: isSelected ? 2 : 1.5),
        borderRadius: BorderRadius.zero,
        boxShadow: isSelected
            ? [BoxShadow(
                color: kAccent.withValues(alpha: 0.5),
                blurRadius: 0,
                offset: const Offset(2, 2))]
            : null,
      ),
      child: isKing
          ? Center(
              child: pixelText('♛', kWarn, 14),
            )
          : null,
    );
  }

  Widget _playerCard({
    required String name,
    required String color,
    required bool isActive,
    required bool isMe,
    required List<String> board,
  }) {
    final count = board.where((p) => p.toLowerCase() == color).length;
    final pieceColor = color == 'w' ? kWhite : kBg;
    final borderColor = color == 'w' ? kWarn : kBlue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? borderColor.withValues(alpha: 0.15) : kPanel,
        border: Border.all(
          color: isActive ? borderColor : kBorder,
          width: 2,
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: isActive
            ? [BoxShadow(
                color: borderColor.withValues(alpha: 0.3),
                blurRadius: 0,
                offset: const Offset(2, 2))]
            : null,
      ),
      child: Column(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: pieceColor,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: pixelText('$count',
                  color == 'w' ? kBg : kWhite, 12),
            ),
          ),
          const SizedBox(height: 4),
          pixelText(
            isMe ? 'SEN' : name.split(' ').first.toUpperCase(),
            kDim, 9,
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: kPanel,
        border: Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.messagesStream(widget.roomCode),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(
                    child: pixelText('HALI XABAR YO\'Q', kDim, 10),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                final docs = snap.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final msg = docs[i].data() as Map<String, dynamic>;
                    final isMe = msg['uid'] == _service.myUid;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? kAccent.withValues(alpha: 0.12)
                                  : kWarn.withValues(alpha: 0.1),
                              border: Border.all(
                                  color: isMe
                                      ? kAccent.withValues(alpha: 0.4)
                                      : kWarn.withValues(alpha: 0.3),
                                  width: 1),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text(
                              msg['text'] ?? '',
                              style: const TextStyle(
                                  color: kWhite,
                                  fontSize: 12,
                                  fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 8, right: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 6,
              top: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(
                        color: kWhite, fontFamily: 'monospace', fontSize: 12),
                    decoration: pixelInputDecoration('XABAR...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: kAccent,
                      border: Border.all(color: kAccent, width: 2),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Center(
                        child: Icon(Icons.send, color: kBg, size: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(
      String status, String? winner, bool isMyTurn, String myColor) {
    if (status == 'waiting') return 'KUTMOQDA...';
    if (status == 'finished') {
      final isWin = winner == myColor;
      return isWin ? 'SIZ G\'ALDINGIZ!' : 'YUTQAZDINGIZ...';
    }
    return isMyTurn ? 'SIZNING NAVBAT' : 'RAQIB NAVBAT';
  }

  Color _statusColor(String status, String? winner, String myColor) {
    if (status == 'finished') {
      return winner == myColor ? kAccent : kDanger;
    }
    return kDim;
  }
}
