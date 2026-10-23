import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/room_service.dart';
import '../services/game_service.dart';
import '../services/checkers_service.dart';
import '../services/quiz_service.dart';
import '../services/ha_yoq_service.dart';
import '../services/word_puzzle_service.dart';
import '../services/scrambled_word_service.dart';
import '../theme/pixel_ui.dart';
import 'tictactoe_screen.dart';
import 'checkers_screen.dart';
import 'quiz_screen.dart';
import 'ha_yoq_screen.dart';
import 'word_puzzle_screen.dart';
import 'scrambled_word_screen.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const RoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final _roomService = RoomService();
  final _gameService = GameService();
  final _checkersService = CheckersService();
  final _quizService = QuizService();
  final _haYoqService = HaYoqService();
  final _wordPuzzleService = WordPuzzleService();
  final _scrambledWordService = ScrambledWordService();

  bool _navigating = false;
  bool _creating = false;
  final _visitedGameCodes = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _roomService.roomStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return pixelLoading();

        if (!snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Xona yopildi')));
              Navigator.pop(context);
            }
          });
          return pixelLoading();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final players = data['players'] as Map<String, dynamic>;
        final hostUid = data['host'] as String;
        final amIHost = _roomService.myUid == hostUid;
        final invite = data['gameInvite'] as Map<String, dynamic>?;

        if (invite != null &&
            invite['response'] == 'accepted' &&
            !_navigating &&
            !_visitedGameCodes.contains(invite['gameCode'] as String)) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToGame(invite, amIHost);
          });
        }

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kPanel,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kAccent),
              onPressed: () async {
                final nav = Navigator.of(context);
                await _roomService.leaveRoom(widget.roomCode);
                nav.pop();
              },
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pixelText('XONA: ', kDim, 11),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kod nusxalandi!')));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      pixelText(widget.roomCode, kWarn, 14),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 13, color: kDim),
                    ],
                  ),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPlayers(players, hostUid),
                  const SizedBox(height: 20),
                  Expanded(child: _buildContent(players, amIHost, invite)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayers(Map<String, dynamic> players, String hostUid) {
    final entries = players.entries.toList();
    return pixelContainer(
      borderColor: kWarn.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ...entries.map((e) {
            final p = e.value as Map;
            final isHostPlayer = e.key == hostUid;
            final isMe = e.key == _roomService.myUid;
            final color = isHostPlayer ? kWarn : kAccent;
            final name = p['name'] as String;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: pixelText(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        color,
                        18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  pixelText(
                    isMe ? '${name.toUpperCase()} (SEN)' : name.toUpperCase(),
                    kWhite,
                    10,
                  ),
                  pixelText(
                    isHostPlayer ? "XO'JAYIN" : 'MEHMON',
                    color,
                    9,
                  ),
                ],
              ),
            );
          }),
          if (players.length < 2)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPanel,
                      border: Border.all(color: kBorder, width: 2),
                    ),
                    child:
                        const Center(child: Icon(Icons.person_add, color: kDim, size: 18)),
                  ),
                  const SizedBox(height: 6),
                  pixelText('KUTILMOQDA...', kDim, 9),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
      Map<String, dynamic> players, bool amIHost, Map<String, dynamic>? invite) {
    if (players.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            pixelText('[ KUTILMOQDA ]', kAccent, 20),
            const SizedBox(height: 16),
            pixelText("IKKINCHI O'YINCHI KUTILMOQDA...", kDim, 11),
            const SizedBox(height: 8),
            pixelText("KODINGIZNI DO'STINGIZGA YUBORING", kDim, 10),
          ],
        ),
      );
    }

    if (invite != null && invite['response'] == null) {
      return amIHost
          ? _buildHostWaiting(invite)
          : _buildGuestInvite(invite, players);
    }

    if (amIHost) return _buildGameSelection();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          pixelText('[ O\'YIN ]', kAccent, 24),
          const SizedBox(height: 16),
          pixelText("XO'JAYIN O'YIN TANLAYAPTI...", kDim, 12),
        ],
      ),
    );
  }

  Widget _buildGameSelection() {
    final games = [
      {'id': 'tictactoe', 'name': 'X-O', 'icon': '✖', 'color': kBlue},
      {'id': 'checkers', 'name': 'SHASHKA', 'icon': '♟', 'color': kWarn},
      {'id': 'quiz', 'name': 'QUIZ', 'icon': '?', 'color': kAccent},
      {'id': 'hayoq', 'name': "HA/YO'Q", 'icon': '!', 'color': const Color(0xFF00CCFF)},
      {'id': 'wordpuzzle', 'name': "SO'Z TOPISH", 'icon': 'A', 'color': kAccent},
      {'id': 'scramble', 'name': 'HARFLAR', 'icon': '#', 'color': kDanger},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pixelText("// O'YIN TANLANG:", kDim, 11, align: TextAlign.left),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            physics: const NeverScrollableScrollPhysics(),
            children: games.map((g) {
              final color = g['color'] as Color;
              return GestureDetector(
                onTap: _creating ? null : () => _selectGame(g['id'] as String),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _creating ? 0.03 : 0.08),
                    border: Border.all(
                        color: color.withValues(alpha: _creating ? 0.2 : 0.6),
                        width: 2),
                    borderRadius: BorderRadius.zero,
                    boxShadow: _creating
                        ? null
                        : [
                            BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 0,
                                offset: const Offset(3, 3)),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      pixelText(g['icon'] as String, color, 28),
                      const SizedBox(height: 6),
                      pixelText(g['name'] as String, color, 11),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_creating)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: pixelText('YARATILMOQDA...', kDim, 11),
            ),
          ),
      ],
    );
  }

  Widget _buildHostWaiting(Map invite) {
    final names = {
      'tictactoe': 'X-O',
      'checkers': 'SHASHKA',
      'quiz': 'QUIZ',
      'hayoq': "HA / YO'Q",
      'wordpuzzle': "SO'Z TOPISH",
      'scramble': 'HARFLAR',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          pixelText('[ TAKLIF YUBORILDI ]', kWarn, 18),
          const SizedBox(height: 16),
          pixelText(names[invite['game']] ?? '', kWhite, 22),
          const SizedBox(height: 8),
          pixelText('JAVOB KUTILMOQDA...', kDim, 11),
          const SizedBox(height: 28),
          pixelButton(
            label: '✕ TAKLIFNI BEKOR QILISH',
            onTap: () => _roomService.rejectInvite(widget.roomCode),
            color: kBg,
            textColor: kDanger,
            borderColor: kDanger,
            fontSize: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestInvite(Map invite, Map<String, dynamic> players) {
    final names = {
      'tictactoe': "X-O O'YINI",
      'checkers': 'SHASHKA',
      'quiz': 'QUIZ',
      'hayoq': "HA YOKI YO'Q",
      'wordpuzzle': "SO'Z TOPISH",
      'scramble': 'HARFLAR',
    };
    final icons = {
      'tictactoe': '✖',
      'checkers': '♟',
      'quiz': '?',
      'hayoq': '!',
      'wordpuzzle': 'A',
      'scramble': '#',
    };
    final hostName =
        (players[invite['invitedBy']] as Map?)?['name']?.toString().toUpperCase() ??
            "XO'JAYIN";
    final gameName = names[invite['game']] ?? invite['game'];
    final icon = icons[invite['game']] ?? '?';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          pixelText(icon, kAccent, 56),
          const SizedBox(height: 16),
          pixelText(gameName, kWhite, 22),
          const SizedBox(height: 8),
          pixelText('$hostName TAKLIF QILDI', kDim, 11),
          const SizedBox(height: 8),
          pixelText('ROZIMISIZ?', kWarn, 14),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _answerBtn('HA', kAccent, () => _acceptInvite(invite)),
              const SizedBox(width: 20),
              _answerBtn("YO'Q", kDanger,
                  () => _roomService.rejectInvite(widget.roomCode)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 0,
                offset: const Offset(3, 3)),
          ],
        ),
        child: Center(child: pixelText(label, color, 18)),
      ),
    );
  }

  Future<int?> _showBoardSizeDialog() {
    return showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: kBorder, width: 2)),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pixelText("TAXTA O'LCHAMINI TANLANG", kAccent, 13),
              const SizedBox(height: 16),
              _sizeOption(ctx, 10, '10 × 10', '100 KATAK', kBlue),
              const SizedBox(height: 10),
              _sizeOption(ctx, 12, '12 × 12', '144 KATAK', kWarn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeOption(
      BuildContext ctx, int size, String label, String desc, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 0,
                offset: const Offset(3, 3)),
          ],
        ),
        child: Row(
          children: [
            pixelText(label, color, 18, align: TextAlign.left),
            const Spacer(),
            pixelText(desc, kDim, 11),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, color: color, size: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _selectGame(String game) async {
    if (_creating) return;

    int gridSize = 10;
    if (game == 'tictactoe') {
      final size = await _showBoardSizeDialog();
      if (size == null) return;
      gridSize = size;
    }

    setState(() => _creating = true);
    try {
      String gameCode;
      switch (game) {
        case 'tictactoe':
          gameCode = await _gameService.createRoom(gridSize: gridSize);
          break;
        case 'checkers':
          gameCode = await _checkersService.createRoom();
          break;
        case 'quiz':
          gameCode = await _quizService.createRoom(10);
          break;
        case 'hayoq':
          gameCode = await _haYoqService.createRoom(5);
          break;
        case 'wordpuzzle':
          final level = await _wordPuzzleService.getUserLevel();
          gameCode = await _wordPuzzleService.createRoom(level: level);
          break;
        case 'scramble':
          gameCode = await _scrambledWordService.createRoom();
          break;
        default:
          return;
      }
      await _roomService.proposeGame(widget.roomCode, game, gameCode);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _acceptInvite(Map invite) async {
    final game = invite['game'] as String;
    final gameCode = invite['gameCode'] as String;
    switch (game) {
      case 'tictactoe':
        await _gameService.joinRoom(gameCode);
        break;
      case 'checkers':
        await _checkersService.joinRoom(gameCode);
        break;
      case 'quiz':
        await _quizService.joinRoom(gameCode);
        break;
      case 'hayoq':
        await _haYoqService.joinRoom(gameCode);
        break;
      case 'wordpuzzle':
        await _wordPuzzleService.joinRoom(gameCode);
        break;
      case 'scramble':
        await _scrambledWordService.joinRoom(gameCode);
        break;
    }
    await _roomService.acceptInvite(widget.roomCode);
  }

  Future<void> _navigateToGame(Map invite, bool amIHost) async {
    final game = invite['game'] as String;
    final gameCode = invite['gameCode'] as String;

    _visitedGameCodes.add(gameCode);

    Widget screen;
    switch (game) {
      case 'tictactoe':
        screen = TicTacToeScreen(roomCode: gameCode, isCreator: amIHost);
        break;
      case 'checkers':
        screen = CheckersScreen(roomCode: gameCode, isCreator: amIHost);
        break;
      case 'quiz':
        screen = QuizScreen(roomCode: gameCode, isHost: amIHost);
        break;
      case 'hayoq':
        screen = HaYoqScreen(roomCode: gameCode, isHost: amIHost);
        break;
      case 'wordpuzzle':
        screen = WordPuzzleScreen(roomCode: gameCode, isHost: amIHost);
        break;
      case 'scramble':
        screen = ScrambledWordScreen(roomCode: gameCode, isHost: amIHost);
        break;
      default:
        _navigating = false;
        return;
    }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

    if (mounted) {
      _navigating = false;
      if (amIHost) await _roomService.resetAfterGame(widget.roomCode);
    }
  }
}
