import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../net/server_client.dart';
import '../../ui/kit.dart';
import '../../ui/setup.dart';
import 'stack_art.dart';
import 'stack_bot.dart';
import 'stack_game.dart';

/// Stack sozlamalari: musobaqa (kompyuter), yolg'iz (rekord) yoki — faqat admin uchun —
/// do'stlar bilan onlayn.
Future<({bool race, bool online, int bots, int level})?> showStackSetup(BuildContext context,
    {bool allowOnline = false}) {
  var race = true;
  var online = false;
  var bots = 2;
  var level = 2;
  const blue = Color(0xFF4FC3F7);
  return showGameSetup(
    context,
    title: 'Stack',
    colors: const [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
    onStart: () => (race: race && !online, online: online, bots: bots, level: level),
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SetupLabel('Rejim'),
        ChoiceRow(children: [
          ChoiceCard(
            selected: race && !online,
            color: blue,
            icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 36),
            label: 'Musobaqa',
            hint: 'kompyuterlar bilan',
            onTap: () => setState(() {
              race = true;
              online = false;
            }),
          ),
          ChoiceCard(
            selected: !race && !online,
            color: blue,
            icon: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
            label: "Yolg'iz",
            hint: 'rekordlar jadvali',
            onTap: () => setState(() {
              race = false;
              online = false;
            }),
          ),
        ]),
        if (allowOnline) ...[
          const SizedBox(height: 10),
          ChoiceCard(
            selected: online,
            color: const Color(0xFF66BB6A),
            icon: const Icon(Icons.wifi_rounded, color: Colors.white, size: 36),
            label: "Do'stlar bilan (onlayn)",
            hint: 'xona oching va havola yuboring',
            onTap: () => setState(() => online = true),
          ),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: !race || online
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const SetupLabel('Nechta kompyuter'),
                    PlayerCountPicker(
                      min: 1,
                      max: 3,
                      value: bots,
                      colors: const [Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF81C784)],
                      onChanged: (n) => setState(() => bots = n),
                    ),
                    const SetupLabel('Kompyuter — smaylikni suring'),
                    DifficultyRope(value: level, onChanged: (v) => setState(() => level = v)),
                  ],
                ),
        ),
      ],
    ),
  );
}

/// Musobaqadagi bitta o'yinchi (yo'lak).
///
/// Hozircha raqiblar — kompyuter. Onlayn rejimda [bot] o'rniga serverdan
/// kelgan "qo'ydi" xabarlari bilan boshqariladi — qolgan hammasi o'zgarmaydi.
class StackLane {
  final String name;
  final bool isMe;
  final StackBot? bot;
  final StackGame game = StackGame();

  /// Onlayn o'yinchi (Telegram uid). Uning yurishlari [pendingMoves] ga keladi.
  final String? id;

  /// Serverdan kelgan, hali qo'llanmagan yurishlar (blok siljishlari).
  final pendingMoves = <double>[];

  /// Nechta yurish allaqachon navbatga qo'yilgan.
  int received = 0;

  /// O'yinchi xonadan chiqib ketdi.
  bool gone = false;

  /// Kamera balandligi (silliq).
  double cam = 0;

  /// Yiqilgan payt (natijada kim keyinroq yiqilgani hisobga olinadi).
  double? fellAt;

  /// "Zo'r!" effekti.
  double perfectAt = -10;

  StackLane(this.name, {this.isMe = false, this.bot, this.id});

  bool get alive => !game.over;
}

/// Musobaqa: 2–4 minora yonma-yon, hamma bir vaqtda quradi.
class StackRaceScreen extends StatefulWidget {
  final int bots;
  final int level;
  final int? seed;

  /// Onlayn: tayyor yo'laklar (birinchisi — siz), sanoq va server bilan aloqa.
  final List<StackLane>? lanes;
  final double countdown;
  final void Function(double offset)? onPlace;
  final VoidCallback? onOver;
  final VoidCallback? onAgain;
  final String title;

  const StackRaceScreen({
    super.key,
    this.bots = 2,
    this.level = 2,
    this.seed,
    this.lanes,
    this.countdown = 3,
    this.onPlace,
    this.onOver,
    this.onAgain,
    this.title = 'Stack — musobaqa',
  });

  @override
  State<StackRaceScreen> createState() => _StackRaceScreenState();
}

class _StackRaceScreenState extends State<StackRaceScreen> with SingleTickerProviderStateMixin {
  static const _botNames = ['Usta', "Me'mor", 'Quruvchi'];
  static const _botColors = [Color(0xFFFF8A65), Color(0xFFBA68C8), Color(0xFF81C784)];

  late final Random _rnd = Random(widget.seed);
  late List<StackLane> _lanes = _newLanes();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _time = 0;

  /// Boshlanishdan oldingi sanoq (3-2-1).
  late double _countdown = widget.countdown;
  double? _endedAt;

  StackLane get _me => _lanes.first;

  static String _myName() {
    final n = ServerClient.instance.user.value?.name.trim() ?? '';
    return n.isEmpty ? 'Siz' : n;
  }

  List<StackLane> _newLanes() => widget.lanes ?? [
        StackLane(_myName(), isMe: true),
        for (var k = 0; k < widget.bots; k++)
          StackLane(_botNames[k], bot: StackBot(widget.level, Random(_rnd.nextInt(1 << 30)))),
      ];

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    _time += dt;
    if (_countdown > 0) {
      final before = _countdown.ceil();
      _countdown -= dt;
      if (_countdown.ceil() != before) HapticFeedback.selectionClick();
      setState(() {});
      return;
    }
    for (final l in _lanes) {
      final wasAlive = l.alive;
      l.game.update(dt);
      // Onlayn raqib: serverdan kelgan yurishlarni aynan o'sha siljishda qo'yamiz
      if (!l.isMe && l.bot == null) {
        while (l.alive && l.pendingMoves.isNotEmpty) {
          final g = l.game;
          g.offset = l.pendingMoves.removeAt(0);
          g.update(0);
          if (g.place() == StackResult.perfect) l.perfectAt = g.time;
        }
        if (l.gone && l.alive) l.game.over = true;
      }
      if (l.alive && l.bot != null && l.bot!.update(l.game, dt)) {
        if (l.game.place() == StackResult.perfect) l.perfectAt = l.game.time;
      }
      if (wasAlive && !l.alive) l.fellAt = _time;
      l.cam += (l.game.score - l.cam) * min(1.0, dt * 6);
    }
    // Siz yiqildingiz, qolganlar faqat kompyuter — kuzatib o'tirish shart emas:
    // ularning o'yini bir zumda oxirigacha hisoblanadi va natija darhol chiqadi
    if (_endedAt == null && !_me.alive && _lanes.every((l) => l.isMe || l.bot != null)) {
      for (final l in _lanes) {
        if (l.alive) _fastForward(l);
      }
    }
    if (_endedAt == null && _lanes.every((l) => !l.alive)) {
      _endedAt = _time;
      HapticFeedback.heavyImpact();
    }
    setState(() {});
  }

  /// Kompyuter o'yinini ko'rsatmasdan oxirigacha o'ynatib qo'yadi.
  void _fastForward(StackLane l) {
    const dt = 1 / 60;
    var t = 0.0;
    final bot = l.bot!;
    while (l.alive && t < 1200) {
      l.game.update(dt);
      t += dt;
      if (bot.update(l.game, dt)) l.game.place();
    }
    l.fellAt = _time + t;
    l.cam = l.game.score.toDouble();
  }

  void _tap() {
    final g = _me.game;
    if (_countdown > 0 || g.over) return;
    widget.onPlace?.call(g.offset);
    switch (g.place()) {
      case StackResult.perfect:
        HapticFeedback.mediumImpact();
        _me.perfectAt = g.time;
      case StackResult.placed:
        HapticFeedback.selectionClick();
      case StackResult.missed:
        HapticFeedback.heavyImpact();
        widget.onOver?.call();
    }
  }

  void _again() {
    if (widget.onAgain != null) {
      widget.onAgain!();
      return;
    }
    setState(() {
      _lanes = _newLanes();
      _countdown = 3;
      _endedAt = null;
      _time = 0;
    });
  }

  /// O'rinlar: ko'p qavat yuqorida, teng bo'lsa — keyinroq yiqilgan.
  List<StackLane> get _ranking => [..._lanes]..sort((a, b) {
      final s = b.game.score.compareTo(a.game.score);
      if (s != 0) return s;
      return (b.fellAt ?? double.infinity).compareTo(a.fellAt ?? double.infinity);
    });

  @override
  Widget build(BuildContext context) {
    final meAlive = _me.alive;
    return GameScaffold(
      title: widget.title,
      palette: GamePalette.stack,
      body: GestureDetector(
        key: const ValueKey('stack-race'),
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: Stack(
          children: [
            // O'ynayotganda — o'z minorangiz katta, raqiblar tepada kichik kartochkalarda.
            // Yiqilgach — hamma minoralar teng yonma-yon (kuzatish).
            if (meAlive)
              _focus()
            else
              Row(
                children: [
                  for (var k = 0; k < _lanes.length; k++) Expanded(child: _lane(_lanes[k], k)),
                ],
              ),
            if (_countdown > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: GlowText('${_countdown.ceil()}', size: 110, color: Colors.white),
                  ),
                ),
              ),
            if (!meAlive && _endedAt == null)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: Center(
                    child: GlowText('Yiqildingiz — qolganlarni kuzatyapsiz', size: 16, color: Colors.white),
                  ),
                ),
              ),
            if (_endedAt != null && _time - _endedAt! > 0.8) Positioned.fill(child: _results()),
          ],
        ),
      ),
    );
  }

  Color _color(int index) =>
      index == 0 ? const Color(0xFF5CFF8A) : _botColors[(index - 1) % _botColors.length];

  /// O'zingiz o'ynayotgan payt: katta minora + tepada raqiblar.
  Widget _focus() {
    final me = _me;
    final sincePerfect = me.game.time - me.perfectAt;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: stackBackground(me.cam),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: StackTowerPainter(
              me.game,
              cam: me.cam,
              showMoving: _countdown <= 0,
              ripple: sincePerfect < 0.6 ? sincePerfect / 0.6 : null,
              topAt: 0.56,
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: IgnorePointer(
            child: Column(
              children: [
                // Raqiblar
                Row(
                  children: [
                    for (var k = 1; k < _lanes.length; k++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _miniCard(_lanes[k], k),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // O'zingizning hisobingiz
                Text(
                  '${me.game.score}',
                  key: const ValueKey('score-0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                ),
                Text(_place(me), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                if (sincePerfect < 0.9)
                  Opacity(
                    opacity: (1 - sincePerfect / 0.9).clamp(0.0, 1.0),
                    child: GlowText(
                      me.game.combo >= 2 ? "Zo'r! ×${me.game.combo}" : "Zo'r!",
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Hozirgi o'rin: "2-o'rinda".
  String _place(StackLane l) => "${_ranking.indexOf(l) + 1}-o'rinda";

  /// Raqibning kichik kartochkasi: jonli minora, ism, hisob.
  Widget _miniCard(StackLane l, int index) {
    final color = _color(index);
    return Container(
      height: 128,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stackBackground(l.cam),
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: l.alive ? 1 : 0.5,
              child: CustomPaint(
                painter: StackTowerPainter(
                  l.game,
                  cam: l.cam,
                  showMoving: _countdown <= 0 && l.alive,
                  topAt: 0.5,
                  widthFactor: 0.55,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 6,
            right: 6,
            child: Row(
              children: [
                Icon(l.bot == null ? Icons.person_rounded : Icons.smart_toy_rounded, color: color, size: 12),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(l.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
                Text('${l.game.score}',
                    key: ValueKey('score-$index'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
          ),
          if (!l.alive)
            const Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Text('Yiqildi',
                    style: TextStyle(color: Color(0xFFFF8A80), fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lane(StackLane l, int index) {
    final color = _color(index);
    final sincePerfect = l.game.time - l.perfectAt;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stackBackground(l.cam),
        ),
        border: Border(right: BorderSide(color: Colors.black.withValues(alpha: 0.35), width: 1.5)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: l.alive ? 1 : 0.55,
              child: CustomPaint(
                painter: StackTowerPainter(
                  l.game,
                  cam: l.cam,
                  showMoving: _countdown <= 0 && l.alive,
                  ripple: sincePerfect < 0.6 ? sincePerfect / 0.6 : null,
                  // Tor yo'lakda minora kengroq chizilsin
                  widthFactor: 0.9,
                ),
              ),
            ),
          ),
          // Ism va hisob
          Positioned(
            top: 8,
            left: 4,
            right: 4,
            child: IgnorePointer(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(l.isMe || l.bot == null ? Icons.person_rounded : Icons.smart_toy_rounded, color: color, size: 14),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          l.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  FittedBox(
                    child: Text(
                      '${l.game.score}',
                      key: ValueKey('score-$index'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))],
                      ),
                    ),
                  ),
                  if (!l.alive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Yiqildi',
                          style: TextStyle(color: Color(0xFFFF8A80), fontSize: 11, fontWeight: FontWeight.w800)),
                    )
                  else if (sincePerfect < 0.8)
                    Opacity(
                      opacity: (1 - sincePerfect / 0.8).clamp(0.0, 1.0),
                      child: const Text("Zo'r!",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _results() {
    final ranking = _ranking;
    final myPlace = ranking.indexOf(_me) + 1;
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Glass(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlowText(
                myPlace == 1 ? '🏆 Siz yutdingiz!' : '$myPlace-o\'rin',
                size: 28,
                color: myPlace == 1 ? const Color(0xFFFFD54F) : Colors.white,
              ),
              const SizedBox(height: 14),
              for (var k = 0; k < ranking.length; k++)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: ranking[k].isMe ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(['🥇', '🥈', '🥉', '4.'][k], style: const TextStyle(fontSize: 18)),
                      ),
                      Expanded(
                        child: Text(
                          ranking[k].name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: ranking[k].isMe ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('${ranking[k].game.score}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              GameButton(
                key: const ValueKey('race-again'),
                label: "Yana o'ynash",
                icon: Icons.replay_rounded,
                colors: const [Color(0xFF4FC3F7), Color(0xFF7C4DFF)],
                onPressed: _again,
              ),
              const SizedBox(height: 10),
              GameButton(
                label: 'Bosh menyu',
                outlined: true,
                colors: const [Colors.white70, Colors.white70],
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
