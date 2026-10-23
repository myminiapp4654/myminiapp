import 'dart:math';

/// Escape the Walls: devorlarni buzib qochib chiqish (bir kishilik, inkremental).
///
/// - G'ishtni urasiz → singanda pul va ba'zan topilma (tanga, kalit, olmos)
/// - Devor to'liq buzilsa — keyingi devor (har biri qattiqroq, lekin qimmatroq)
/// - [finalWall] dan o'tsangiz — qochib chiqdingiz; qayta boshlasangiz daromad +25%
/// - Asboblar zarbani kuchaytiradi, ishchilar devorni o'zi buzadi
/// - Ichida tuzoqlar bor: tok (qo'l bir necha soniya ishlamaydi), qulash
///   (buzilgan g'ishtlar qayta paydo bo'ladi)
enum BrickType { normal, stone, metal, treasure, shock, collapse }

class Brick {
  BrickType type;
  double maxHp;
  double hp;

  Brick(this.type, this.maxHp) : hp = maxHp;

  bool get broken => hp <= 0;
  bool get isTrap => type == BrickType.shock || type == BrickType.collapse;

  Map<String, dynamic> toJson() => {'t': type.index, 'm': maxHp, 'h': hp};

  factory Brick.fromJson(Map<String, dynamic> j) =>
      Brick(BrickType.values[j['t'] as int], (j['m'] as num).toDouble())
        ..hp = (j['h'] as num).toDouble();
}

/// Bitta zarba natijasi (ekranda ko'rsatish uchun).
class HitResult {
  final double damage;
  final bool crit;
  final bool broken;
  final double gained;
  final String? loot;
  final BrickType? trap;
  final bool wallCleared;

  const HitResult({
    this.damage = 0,
    this.crit = false,
    this.broken = false,
    this.gained = 0,
    this.loot,
    this.trap,
    this.wallCleared = false,
  });

  static const none = HitResult();
}

class Tool {
  final String name;
  final double power;
  final double price;
  const Tool(this.name, this.power, this.price);
}

class WallsGame {
  static const rows = 8;
  static const cols = 6;
  static const finalWall = 25;

  static const tools = [
    Tool('Musht', 1, 0),
    Tool("Bolg'a", 4, 60),
    Tool('Lom', 12, 600),
    Tool('Drel', 35, 5000),
    Tool('Perforator', 100, 40000),
  ];

  /// Topilmalar: nomi va g'isht qiymatiga ko'paytiruvchi.
  static const _loot = [('Tanga', 5.0), ('Eski kalit', 12.0), ('Olmos', 40.0)];

  final Random _rnd;

  int wall = 1;
  double money = 0;
  int escapes = 0;
  bool escaped = false;

  int tool = 0;
  int powerLvl = 0;
  int critLvl = 0;
  int workerLvl = 0;
  int luckLvl = 0;
  bool scanner = false;
  bool insulation = false;
  int dynamite = 0;

  /// Tok urgandan keyin qo'l ishlamaydigan vaqt (soniya).
  double stunned = 0;

  late List<Brick> bricks;
  double _workerDamage = 0;

  WallsGame({Random? random}) : _rnd = random ?? Random() {
    _buildWall();
  }

  // ---------------------------------------------------------------- hisob-kitob

  double get toolPower => tools[tool].power;
  double get tapDamage => (1 + powerLvl) * toolPower;
  double get critChance => min(0.5, critLvl * 0.05);
  double get dps => workerLvl * 0.6 * toolPower;
  double get incomeMultiplier => 1 + 0.25 * escapes;
  double get lootChance => 0.03 + luckLvl * 0.015;
  int get bricksLeft => bricks.where((b) => !b.broken).length;

  double get _baseHp => 3 * pow(1.32, wall - 1).toDouble();
  double get _baseValue => 1.2 * pow(1.28, wall - 1).toDouble();

  static double _hpFactor(BrickType t) => switch (t) {
        BrickType.stone => 3,
        BrickType.metal => 8,
        BrickType.treasure => 1.5,
        _ => 1,
      };

  static double _valueFactor(BrickType t) => switch (t) {
        BrickType.stone => 2,
        BrickType.metal => 4,
        BrickType.treasure => 25,
        _ => 1,
      };

  // ---------------------------------------------------------------- devor

  BrickType _randomType() {
    final r = _rnd.nextDouble();
    var edge = 0.0;
    bool roll(double p) => r < (edge += p);
    if (wall >= 3 && roll(0.05)) return BrickType.shock;
    if (wall >= 5 && roll(0.04)) return BrickType.collapse;
    if (roll(0.05 + luckLvl * 0.01)) return BrickType.treasure;
    if (wall >= 4 && roll(min(0.25, 0.06 + wall * 0.01))) return BrickType.metal;
    if (wall >= 2 && roll(min(0.35, 0.12 + wall * 0.01))) return BrickType.stone;
    return BrickType.normal;
  }

  void _buildWall() {
    bricks = [
      for (var i = 0; i < rows * cols; i++)
        () {
          final t = _randomType();
          return Brick(t, _baseHp * _hpFactor(t));
        }(),
    ];
  }

  /// Tuzoq va xazinalar faqat skaner bilan ko'rinadi.
  bool isRevealed(int i) => scanner || bricks[i].broken;

  // ---------------------------------------------------------------- zarba

  /// Barmoq bilan urish.
  HitResult tap(int i) {
    if (escaped || stunned > 0 || bricks[i].broken) return HitResult.none;
    final crit = _rnd.nextDouble() < critChance;
    var damage = tapDamage * (crit ? 3 : 1);
    // Temirni musht bilan deyarli sindirib bo'lmaydi
    if (bricks[i].type == BrickType.metal && tool == 0) damage *= 0.1;
    return _damage(i, damage, crit: crit);
  }

  HitResult _damage(int i, double damage,
      {bool crit = false, bool safe = false}) {
    final b = bricks[i];
    if (b.broken) return HitResult.none;
    b.hp -= damage;
    if (!b.broken) return HitResult(damage: damage, crit: crit);
    b.hp = 0;

    var gained = _baseValue * _valueFactor(b.type) * incomeMultiplier;
    String? loot;
    if (b.type == BrickType.treasure || _rnd.nextDouble() < lootChance) {
      final item = _loot[b.type == BrickType.treasure
          ? 2
          : _rnd.nextInt(_loot.length)];
      loot = item.$1;
      gained += _baseValue * item.$2 * incomeMultiplier;
    }
    money += gained;

    BrickType? trap;
    if (b.isTrap && !safe) {
      trap = b.type;
      if (b.type == BrickType.shock && !insulation) stunned = 2.5;
      if (b.type == BrickType.collapse) _collapse(i);
    }

    final cleared = _checkCleared();
    return HitResult(
      damage: damage,
      crit: crit,
      broken: true,
      gained: gained,
      loot: loot,
      trap: trap,
      wallCleared: cleared,
    );
  }

  /// Qulash: 2 ta buzilgan g'isht qayta paydo bo'ladi.
  void _collapse(int origin) {
    final broken = [
      for (var k = 0; k < bricks.length; k++)
        if (bricks[k].broken && k != origin) k,
    ]..shuffle(_rnd);
    for (final k in broken.take(2)) {
      bricks[k] = Brick(BrickType.normal, _baseHp);
    }
  }

  bool _checkCleared() {
    if (bricks.any((b) => !b.broken)) return false;
    wall++;
    if (wall > finalWall) {
      escaped = true;
      wall = finalWall;
    } else {
      _buildWall();
    }
    return true;
  }

  /// Dinamit: 3×3 maydonni portlatadi, tuzoqlar ishlamaydi.
  List<HitResult> useDynamite(int i) {
    if (dynamite <= 0 || escaped) return const [];
    dynamite--;
    final r = i ~/ cols, c = i % cols;
    final results = <HitResult>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final rr = r + dr, cc = c + dc;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) continue;
        final k = rr * cols + cc;
        if (bricks[k].broken) continue;
        final res = _damage(k, bricks[k].hp, safe: true);
        results.add(res);
        if (res.wallCleared) return results; // yangi devor boshlandi
      }
    }
    return results;
  }

  /// Vaqt o'tishi: ishchilar devorni buzadi, tok ta'siri o'tadi.
  List<HitResult> tick(double dt) {
    if (stunned > 0) stunned = max(0, stunned - dt);
    if (escaped || dps <= 0) return const [];
    _workerDamage += dps * dt;
    final results = <HitResult>[];
    // Ishchilar eng zaif g'ishtdan boshlaydi
    while (_workerDamage > 0) {
      final target = _weakest();
      if (target == null) break;
      final need = bricks[target].hp;
      if (_workerDamage < need) {
        bricks[target].hp -= _workerDamage;
        _workerDamage = 0;
        break;
      }
      _workerDamage -= need;
      final res = _damage(target, need, safe: true);
      results.add(res);
      if (escaped) break;
    }
    return results;
  }

  int? _weakest() {
    int? best;
    for (var k = 0; k < bricks.length; k++) {
      if (bricks[k].broken) continue;
      if (best == null || bricks[k].hp < bricks[best].hp) best = k;
    }
    return best;
  }

  // ---------------------------------------------------------------- do'kon

  double get powerCost => 15 * pow(1.5, powerLvl).toDouble();
  double get critCost => 50 * pow(1.7, critLvl).toDouble();
  double get workerCost => 30 * pow(1.6, workerLvl).toDouble();
  double get luckCost => 80 * pow(1.8, luckLvl).toDouble();
  double get dynamiteCost => 40 * pow(1.25, wall - 1).toDouble();
  static const scannerCost = 250.0;
  static const insulationCost = 400.0;

  bool get critMaxed => critLvl >= 10;
  bool get luckMaxed => luckLvl >= 10;

  bool _pay(double cost) {
    if (money < cost) return false;
    money -= cost;
    return true;
  }

  bool buyTool() {
    if (tool >= tools.length - 1) return false;
    if (!_pay(tools[tool + 1].price)) return false;
    tool++;
    return true;
  }

  bool buyPower() => _pay(powerCost) && (++powerLvl > 0);
  bool buyCrit() => !critMaxed && _pay(critCost) && (++critLvl > 0);
  bool buyWorker() => _pay(workerCost) && (++workerLvl > 0);
  bool buyLuck() => !luckMaxed && _pay(luckCost) && (++luckLvl > 0);
  bool buyDynamite() => _pay(dynamiteCost) && (++dynamite > 0);

  bool buyScanner() {
    if (scanner || !_pay(scannerCost)) return false;
    return scanner = true;
  }

  bool buyInsulation() {
    if (insulation || !_pay(insulationCost)) return false;
    return insulation = true;
  }

  /// Qochib chiqqandan keyin boshidan, daromad +25%.
  void restartAfterEscape() {
    if (!escaped) return;
    escapes++;
    wall = 1;
    money = 0;
    escaped = false;
    tool = powerLvl = critLvl = workerLvl = luckLvl = dynamite = 0;
    scanner = insulation = false;
    stunned = 0;
    _workerDamage = 0;
    _buildWall();
  }

  // ---------------------------------------------------------------- saqlash

  Map<String, dynamic> toJson() => {
        'wall': wall,
        'money': money,
        'escapes': escapes,
        'escaped': escaped,
        'tool': tool,
        'power': powerLvl,
        'crit': critLvl,
        'worker': workerLvl,
        'luck': luckLvl,
        'scanner': scanner,
        'insulation': insulation,
        'dynamite': dynamite,
        'bricks': [for (final b in bricks) b.toJson()],
      };

  factory WallsGame.fromJson(Map<String, dynamic> j, {Random? random}) {
    final g = WallsGame(random: random)
      ..wall = j['wall'] as int
      ..money = (j['money'] as num).toDouble()
      ..escapes = j['escapes'] as int
      ..escaped = j['escaped'] as bool
      ..tool = j['tool'] as int
      ..powerLvl = j['power'] as int
      ..critLvl = j['crit'] as int
      ..workerLvl = j['worker'] as int
      ..luckLvl = j['luck'] as int
      ..scanner = j['scanner'] as bool
      ..insulation = j['insulation'] as bool
      ..dynamite = j['dynamite'] as int;
    final saved = (j['bricks'] as List)
        .map((e) => Brick.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (saved.length == rows * cols) g.bricks = saved;
    return g;
  }
}
