import 'dart:math';

/// Pichoq otish (Knife Hit).
///
/// Markazda nishon (yog'och) aylanadi. Bosilganda pastdan pichoq uchadi va
/// nishonning eng pastki nuqtasiga sanchiladi. Avval sanchilgan pichoqqa
/// tegsa — o'yin tugaydi. Bosqichdagi barcha pichoqlar sanchilsa — nishon
/// parchalanadi va keyingi bosqich boshlanadi. Olmaga tegsa — bonus.
/// Har 5-bosqich — "boss": tezroq va g'alati aylanadi.
class KnifeGame {
  /// Pichoqlar orasidagi eng kichik burchak (radian) — undan yaqin bo'lsa to'qnashadi.
  static const knifeGap = 0.26;
  static const appleGap = 0.22;

  /// Pichoq uchish vaqti (soniya).
  static const flight = 0.11;

  final Random _r;
  int stage = 1;

  /// Nishonning burilish burchagi (radian).
  double angle = 0;
  double time = 0;

  /// Bosqich boshlanganidan beri vaqt (aylanish naqshi uchun).
  double stageTime = 0;

  /// Nishonga sanchilgan pichoqlar — nishonga nisbatan burchaklari.
  final knives = <StuckKnife>[];
  final apples = <double>[];

  /// Bosqichda otish kerak bo'lgan va qolgan pichoqlar.
  int stageKnives = 0;
  int left = 0;

  /// Uchayotgan pichoq (otilgan payt) — null bo'lsa yo'q.
  double? flyingSince;

  int score = 0;
  int applesHit = 0;
  bool over = false;

  /// Bosqich tugadi — nishon parchalanyapti (yangi bosqichgacha).
  double? clearedAt;

  /// Oxirgi voqealar (ekranda effekt uchun).
  final events = <KnifeEvent>[];

  late RotationPattern pattern;

  KnifeGame({int? seed}) : _r = Random(seed) {
    _setupStage();
  }

  bool get isBoss => stage % 5 == 0;

  /// Pastki nuqta (pichoq tegadigan joy) nishonga nisbatan qaysi burchakda.
  double get hitAngle => _norm(pi / 2 - angle);

  static double _norm(double a) {
    final t = a % (2 * pi);
    return t < 0 ? t + 2 * pi : t;
  }

  static double _diff(double a, double b) {
    final d = (a - b).abs() % (2 * pi);
    return d > pi ? 2 * pi - d : d;
  }

  void _setupStage() {
    knives.clear();
    apples.clear();
    stageTime = 0;
    clearedAt = null;
    flyingSince = null;
    // Nishonga sig'adigan bo'lishi kerak: pichoqlar + to'siqlar 13 tadan oshmaydi
    stageKnives = min(5 + stage ~/ 3 + (isBoss ? 1 : 0), 9);
    left = stageKnives;
    pattern = RotationPattern.forStage(stage, _r);

    // Oldindan sanchilgan pichoqlar (to'siqlar) — bosqich sari ko'payadi
    final obstacles = isBoss ? min(2 + stage ~/ 10, 4) : min((stage - 1) ~/ 3, 3);
    var tries = 0;
    while (knives.length < obstacles && tries++ < 200) {
      final a = _r.nextDouble() * 2 * pi;
      if (knives.every((k) => _diff(k.angle, a) > knifeGap * 2.2)) {
        knives.add(StuckKnife(a, preset: true));
      }
    }
    // Olmalar
    final appleCount = _r.nextDouble() < (isBoss ? 0.9 : 0.6) ? 1 + (stage > 6 ? _r.nextInt(2) : 0) : 0;
    tries = 0;
    while (apples.length < appleCount && tries++ < 200) {
      final a = _r.nextDouble() * 2 * pi;
      if (knives.every((k) => _diff(k.angle, a) > appleGap * 1.5) && apples.every((x) => _diff(x, a) > 0.5)) {
        apples.add(a);
      }
    }
  }

  /// Bosish: pichoq otiladi (uchayotgan bo'lsa yoki bosqich tugayotgan bo'lsa — yo'q).
  bool throwKnife() {
    if (over || flyingSince != null || clearedAt != null || left <= 0) return false;
    flyingSince = time;
    left--;
    return true;
  }

  void update(double dt) {
    time += dt;
    events.removeWhere((e) => time - e.at > 2);
    if (over) return;

    if (clearedAt != null) {
      // Nishon parchalandi — biroz kutib, keyingi bosqich
      if (time - clearedAt! > 1.1) {
        stage++;
        _setupStage();
      }
      return;
    }

    stageTime += dt;
    angle += pattern.speedAt(stageTime) * dt;

    final f = flyingSince;
    if (f != null && time - f >= flight) {
      flyingSince = null;
      _land();
    }
  }

  void _land() {
    final a = hitAngle;
    // Sanchilgan pichoqqa tegdi — o'yin tugadi
    if (knives.any((k) => _diff(k.angle, a) < knifeGap)) {
      over = true;
      events.add(KnifeEvent(KnifeEventType.fail, time, a));
      return;
    }
    knives.add(StuckKnife(a));
    score++;
    events.add(KnifeEvent(KnifeEventType.hit, time, a));
    // Olma
    final apple = apples.where((x) => _diff(x, a) < appleGap).firstOrNull;
    if (apple != null) {
      apples.remove(apple);
      applesHit++;
      events.add(KnifeEvent(KnifeEventType.apple, time, apple));
    }
    if (left == 0) {
      clearedAt = time;
      events.add(KnifeEvent(KnifeEventType.cleared, time, a));
    }
  }
}

class StuckKnife {
  final double angle;
  final bool preset;
  StuckKnife(this.angle, {this.preset = false});
}

enum KnifeEventType { hit, apple, fail, cleared }

class KnifeEvent {
  final KnifeEventType type;
  final double at;
  final double angle;
  KnifeEvent(this.type, this.at, this.angle);
}

/// Nishonning aylanish naqshi: tezlik vaqtga qarab o'zgaradi.
class RotationPattern {
  final double base;
  final int kind; // 0 — tekis, 1 — tezlashib-sekinlashadi, 2 — teskari buriladi, 3 — to'xtab-yuradi
  final double period;
  final double dir;

  RotationPattern(this.base, this.kind, this.period, this.dir);

  factory RotationPattern.forStage(int stage, Random r) {
    final boss = stage % 5 == 0;
    final base = min(1.6 + stage * 0.12, 3.6) * (boss ? 1.15 : 1);
    final kind = stage <= 2 ? 0 : (boss ? 2 + r.nextInt(2) : r.nextInt(stage < 6 ? 2 : 4));
    return RotationPattern(base, kind, 1.6 + r.nextDouble() * 1.4, r.nextBool() ? 1 : -1);
  }

  /// Tezlik (radian/soniya) [t] vaqtda.
  double speedAt(double t) {
    switch (kind) {
      case 1:
        return dir * base * (0.45 + 0.85 * (0.5 + 0.5 * sin(2 * pi * t / period)));
      case 2:
        // Har davrda yo'nalish almashadi (silliq)
        return dir * base * 1.1 * sin(2 * pi * t / (period * 2)).sign * min(1, (sin(2 * pi * t / (period * 2))).abs() * 4);
      case 3:
        // Yuradi — to'xtaydi
        final phase = (t % period) / period;
        return dir * base * (phase < 0.65 ? 1.3 : 0.05);
      default:
        return dir * base;
    }
  }
}
