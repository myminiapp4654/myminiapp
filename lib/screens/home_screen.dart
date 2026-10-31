import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../games/battleship/battleship_screen.dart';
import '../games/chain/chain_screen.dart';
import '../games/checkers/checkers_screen.dart';
import '../games/chess/chess_screen.dart';
import '../games/maze/maze_screen.dart';
import '../games/snake/snake_screen.dart';
import '../games/snakes/snakes_screen.dart';
import '../games/stack/stack_online_screen.dart';
import '../games/stack/stack_race_screen.dart';
import '../games/stack/stack_screen.dart';
import '../games/knife/knife_screen.dart';
import '../games/xo/xo_screen.dart';
import '../net/server_client.dart';
import 'admin_users_screen.dart';
import 'online_room_screen.dart';
import '../telegram/telegram.dart';
import '../ui/game_art.dart';
import '../ui/kit.dart';
import '../ui/setup.dart';

class _GameInfo {
  final String title;
  final String tag;
  final GameArt art;
  final List<Color> colors;
  final Future<void> Function(BuildContext) open;
  const _GameInfo(this.title, this.tag, this.art, this.colors, this.open);
}

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.push(context, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ));

Future<void> _openXo(BuildContext context) async {
  var size = 3;
  var level = 2;
  const cyan = Color(0xFF4DE8FF);
  final picked = await showGameSetup<({int size, int level})>(
    context,
    title: 'X-O',
    colors: const [Color(0xFF4DE8FF), Color(0xFF7B5CFF)],
    onStart: () => (size: size, level: level),
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLabel("Taxta o'lchami"),
        ChoiceRow(children: [
          ChoiceCard(
            selected: size == 3,
            color: cyan,
            icon: const MiniGrid(cols: 3, rows: 3, color: Colors.white),
            label: '3 × 3',
            hint: '3 tasi qatorda',
            onTap: () => setState(() => size = 3),
          ),
          ChoiceCard(
            selected: size == 10,
            color: cyan,
            icon: const MiniGrid(cols: 10, rows: 10, color: Colors.white),
            label: '10 × 10',
            hint: '5 tasi qatorda',
            onTap: () => setState(() => size = 10),
          ),
        ]),
        const SizedBox(height: 10),
        const SetupLabel('Kompyuter — smaylikni suring'),
        DifficultyRope(value: level, onChanged: (v) => setState(() => level = v)),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  await _push(context, XoScreen(size: picked.size, level: picked.level));
}

/// Oddiy foydalanuvchilarga ko'rinadigan o'yinlar (admin hammasini ko'radi).
const _publicGames = ['Stack', 'Shaxmat', 'Shashka', 'Neon Snake'];

final _games = <_GameInfo>[
  _GameInfo('Ilon va narvon', 'Har safar yangi taxta', GameArt.snakes,
      const [Color(0xFF43A047), Color(0xFF1B4D2B)], (context) async {
    final bots = await showSnakesSetup(context);
    if (bots == null || !context.mounted) return;
    await _push(context, SnakesScreen(players: bots + 1));
  }),
  _GameInfo('Shaxmat', "Kompyuter • do'st bilan", GameArt.chess,
      const [Color(0xFF8E5A2B), Color(0xFF3B2412)], (context) async {
    {
      final online = await showModeSetup(context,
          title: 'Shaxmat', colors: const [Color(0xFFE8C07A), Color(0xFF8E5A2B)]);
      if (online == null || !context.mounted) return;
      if (online) return OnlineRoomScreen.create(context, 'chess');
    }
    final s = await showChessSetup(context);
    if (s == null || !context.mounted) return;
    await _push(context,
        ChessScreen(vsAi: true, humanColor: s.humanColor, level: s.level));
  }),
  _GameInfo('Dengiz jangi', 'Kompyuterga qarshi', GameArt.battleship,
      const [Color(0xFF0B5FA5), Color(0xFF052848)],
      (context) async {
    final level = await showLevelSetup(context,
        title: 'Dengiz jangi', colors: const [Color(0xFF4FD1FF), Color(0xFF1565C0)]);
    if (level == null || !context.mounted) return;
    await _push(context, BattleshipScreen(level: level));
  }),
  _GameInfo('Shashka', "Kompyuter • do'st bilan", GameArt.checkers,
      const [Color(0xFFE65100), Color(0xFF6D1B00)],
      (context) async {
    {
      final online = await showModeSetup(context,
          title: 'Shashka', colors: const [Color(0xFFFFB347), Color(0xFFE65100)]);
      if (online == null || !context.mounted) return;
      if (online) return OnlineRoomScreen.create(context, 'checkers');
    }
    final level = await showLevelSetup(context,
        title: 'Shashka', colors: const [Color(0xFFFFB347), Color(0xFFE65100)]);
    if (level == null || !context.mounted) return;
    await _push(context, CheckersScreen(level: level));
  }),
  _GameInfo('X-O', 'Kompyuterga qarshi', GameArt.xo,
      const [Color(0xFF1D4ED8), Color(0xFF0B1A4A)], _openXo),
  _GameInfo('Labirint', "Yo'lni chizing", GameArt.maze,
      const [Color(0xFFB4532A), Color(0xFF3A1A0C)], (context) async {
    final level = await showLevelSetup(context,
        title: 'Labirint', colors: const [Color(0xFFFFC233), Color(0xFFB4532A)]);
    if (level == null || !context.mounted) return;
    await _push(context, MazeScreen(level: level));
  }),
  _GameInfo('Neon Snake', 'Eng uzun ilon bo\'ling', GameArt.snake,
      const [Color(0xFF00B8C4), Color(0xFF0B0820)], (context) async {
    {
      final online = await showModeSetup(context,
          title: 'Neon Snake', colors: const [Color(0xFF00F5FF), Color(0xFFB967FF)]);
      if (online == null || !context.mounted) return;
      if (online) return OnlineRoomScreen.create(context, 'snake');
    }
    final level = await showLevelSetup(context,
        title: 'Neon Snake', colors: const [Color(0xFF00F5FF), Color(0xFFB967FF)]);
    if (level == null || !context.mounted) return;
    await _push(context, SnakeScreen(level: level));
  }),
  _GameInfo('Chain Reaction', '1–7 kompyuter', GameArt.chain,
      const [Color(0xFFE91E63), Color(0xFF4A0D2E)], (context) async {
    final s = await showChainSetup(context);
    if (s == null || !context.mounted) return;
    await _push(context,
        ChainScreen(players: s.players, rows: s.rows, cols: s.cols, level: s.level));
  }),
  _GameInfo('Stack', 'Minora musobaqasi', GameArt.stack,
      const [Color(0xFF3D7BD9), Color(0xFF14254A)],
      (context) async {
    final s = await showStackSetup(context, allowOnline: true);
    if (s == null || !context.mounted) return;
    if (s.online) return StackOnlineScreen.create(context);
    await _push(context, s.race ? StackRaceScreen(bots: s.bots, level: s.level) : const StackScreen());
  }),
  _GameInfo('Pichoq otish', 'Bir bosish — nishonga', GameArt.knife,
      const [Color(0xFF7B2FF7), Color(0xFF2A1B4D)],
      (context) => _push(context, const KnifeScreen())),
];

/// Bosh ekran: o'yinlar galereyasi.
class HomeScreen extends StatefulWidget {
  /// Testlar uchun: barcha o'yinlarni ko'rsatish (null — admin bo'yicha).
  final bool? allGames;

  const HomeScreen({super.key, this.allGames});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Taklif havolasi bilan ochilgan bo'lsa — bir marta xonaga o'tamiz.
  static bool _startHandled = false;

  @override
  void initState() {
    super.initState();
    final start = Telegram.startParam;
    if (!_startHandled && start != null) {
      // Taklif havolasi: stack_<KOD> yoki play_<KOD>
      Widget? screen;
      if (start.startsWith(kStackLinkPrefix)) {
        screen = StackOnlineScreen(code: start.substring(kStackLinkPrefix.length));
      } else if (start.startsWith(kPlayLinkPrefix)) {
        screen = OnlineRoomScreen(code: start.substring(kPlayLinkPrefix.length));
      }
      if (screen != null) {
        _startHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
        });
      }
    }
  }

  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..forward();
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Admin (yoki dasturchi debug rejimida) — barcha o'yinlar, qolganlar — faqat Stack.
  List<_GameInfo> get _visible {
    final all = widget.allGames ?? (kDebugMode || (ServerClient.instance.user.value?.admin ?? false));
    if (all) return _games;
    return [for (final t in _publicGames) ..._games.where((g) => g.title == t)];
  }

  @override
  Widget build(BuildContext context) {
    final name = ServerClient.instance.user.value?.name;
    final games = _visible;
    final single = games.length == 1;
    return GameScaffold(
      title: 'BREAK TIME',
      palette: GamePalette.home,
      centerTitle: false,
      actions: [
        // Faqat admin: botga kirganlar
        if (kDebugMode || (ServerClient.instance.user.value?.admin ?? false))
          IconButton(
            key: const ValueKey('admin-users'),
            tooltip: 'Foydalanuvchilar',
            icon: const Icon(Icons.people_alt_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
            ),
          ),
        // Murojaat uchun — bosilsa Telegram profil ochiladi
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: GestureDetector(
              key: const ValueKey('contact'),
              onTap: () => Telegram.openLink('https://t.me/Ulugbeck_dev'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, color: Color(0xFF4FC3F7), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Murojaat: @Ulugbeck_dev',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            sliver: SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _intro,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name == null ? 'Salom! 👋' : 'Salom, $name! 👋',
                        style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text("Bugun nima o'ynaymiz?",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverGrid(
              // Bitta o'yin bo'lsa — katta kartochka
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: single ? 1 : 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: single ? 1.05 : 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final start = (i * 0.08).clamp(0.0, 0.6);
                  final anim = CurvedAnimation(
                    parent: _intro,
                    curve: Interval(start, start + 0.4, curve: Curves.easeOutBack),
                  );
                  return AnimatedBuilder(
                    animation: anim,
                    builder: (_, child) => Opacity(
                      opacity: anim.value.clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - anim.value)),
                        child: child,
                      ),
                    ),
                    child: _GameTile(info: games[i], loop: _loop),
                  );
                },
                childCount: games.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatefulWidget {
  final _GameInfo info;
  final Animation<double> loop;
  const _GameTile({required this.info, required this.loop});

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.info;
    return GestureDetector(
      key: ValueKey('game-${g.title}'),
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () => g.open(context),
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: g.colors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: g.colors.first.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  left: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: 0.25),
                        Colors.white.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: widget.loop,
                            builder: (_, _) => CustomPaint(
                              size: Size.infinite,
                              painter: GameArtPainter(g.art, widget.loop.value),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          )),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(g.tag,
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
