import 'dart:math';

/// Chain Burst (Boomshine / Chain Reaction uslubida) — bir kishilik.
///
/// - Maydonda sharlar o'z-o'zidan suzib, devorlardan qaytib yuradi
/// - Har darajada FAQAT BIR MARTA bosasiz: o'sha joyda portlash halqasi paydo bo'ladi
/// - Halqa kattalashadi, biroz turadi va so'nadi
/// - Halqaga tekkan shar ham portlaydi — zanjir davom etadi
/// - Darajadan o'tish uchun kamida [OrbsLevel.target] ta sharni ushlash kerak
/// - Zanjirning har keyingi bo'g'ini ko'proq ochko beradi
class Orb {
  double x, y, vx, vy;
  final int color;
  bool alive = true;
  Orb(this.x, this.y, this.vx, this.vy, this.color);
}

/// Portlash halqasi.
class Blast {
  final double x, y;
  final int color;

  /// Zanjirdagi bo'g'in: 0 — sizning bosishingiz.
  final int generation;
  double age = 0;

  Blast(this.x, this.y, this.color, this.generation);

  static const grow = 0.25, hold = 1.0, shrink = 0.35;
  static const life = grow + hold + shrink;

  bool get done => age >= life;

  /// Hozirgi radius (maksimumga nisbatan 0..1).
  double get scale {
    if (age < grow) return _easeOut(age / grow);
    if (age < grow + hold) return 1;
    return max(0, 1 - (age - grow - hold) / shrink);
  }
}

double _easeOut(double t) => 1 - pow(1 - t, 3).toDouble();

class OrbsLevel {
  final int total;
  final int target;
  const OrbsLevel(this.total, this.target);
}

enum OrbsResult { playing, won, lost }

/// Ushlangan shar haqida (ekranda "+100" ko'rsatish uchun).
class Catch {
  final double x, y;
  final int points;
  final int generation;
  final double time;
  Catch(this.x, this.y, this.points, this.generation, this.time);
}

class OrbsGame {
  /// Maydon o'lchami (nisbiy birlik).
  static const width = 9.0;
  static const height = 14.0;
  static const orbRadius = 0.22;
  static const blastRadius = 1.25;
  static const colors = 6;

  /// Boomshine darajalari: jami sharlar va ushlash kerak bo'lganlar.
  static const levels = [
    OrbsLevel(5, 1),
    OrbsLevel(10, 2),
    OrbsLevel(15, 3),
    OrbsLevel(20, 5),
    OrbsLevel(25, 7),
    OrbsLevel(30, 10),
    OrbsLevel(35, 15),
    OrbsLevel(40, 21),
    OrbsLevel(45, 27),
    OrbsLevel(50, 33),
    OrbsLevel(55, 44),
    OrbsLevel(60, 55),
  ];

  final int level;
  late final List<Orb> orbs;
  final blasts = <Blast>[];

  /// Shu daraja davomida ushlanganlar (oxirgisi — eng yangi).
  final catches = <Catch>[];

  bool tapped = false;
  int caught = 0;
  int score = 0;
  int maxGeneration = 0;
  double time = 0;

  OrbsGame(this.level, {int? seed}) {
    final rnd = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final n = info.total;
    orbs = [
      for (var k = 0; k < n; k++)
        () {
          final a = rnd.nextDouble() * 2 * pi;
          final speed = 1.4 + rnd.nextDouble() * 1.2;
          return Orb(
            orbRadius + rnd.nextDouble() * (width - 2 * orbRadius),
            orbRadius + rnd.nextDouble() * (height - 2 * orbRadius),
            cos(a) * speed,
            sin(a) * speed,
            rnd.nextInt(colors),
          );
        }(),
    ];
  }

  static int get levelCount => levels.length;

  OrbsLevel get info => levels[(level - 1).clamp(0, levels.length - 1)];

  bool get finished => tapped && blasts.isEmpty;

  OrbsResult get result {
    if (!finished) return OrbsResult.playing;
    return caught >= info.target ? OrbsResult.won : OrbsResult.lost;
  }

  /// Bitta bosish: o'sha joyda portlash boshlanadi.
  bool tap(double x, double y) {
    if (tapped) return false;
    tapped = true;
    blasts.add(Blast(x.clamp(0, width), y.clamp(0, height), -1, 0));
    return true;
  }

  /// Vaqtni [dt] soniyaga suradi.
  void update(double dt) {
    var left = min(dt, 0.1);
    while (left > 1e-9) {
      final h = min(left, 1 / 120);
      _step(h);
      left -= h;
    }
  }

  void _step(double h) {
    time += h;
    for (final o in orbs) {
      if (!o.alive) continue;
      o.x += o.vx * h;
      o.y += o.vy * h;
      if (o.x < orbRadius) {
        o.x = orbRadius;
        o.vx = o.vx.abs();
      } else if (o.x > width - orbRadius) {
        o.x = width - orbRadius;
        o.vx = -o.vx.abs();
      }
      if (o.y < orbRadius) {
        o.y = orbRadius;
        o.vy = o.vy.abs();
      } else if (o.y > height - orbRadius) {
        o.y = height - orbRadius;
        o.vy = -o.vy.abs();
      }
    }

    for (final b in blasts) {
      b.age += h;
    }

    // Halqaga tekkan sharlar portlaydi
    final fresh = <Blast>[];
    for (final b in blasts) {
      final r = blastRadius * b.scale + orbRadius;
      if (r <= orbRadius) continue;
      for (final o in orbs) {
        if (!o.alive) continue;
        final dx = o.x - b.x, dy = o.y - b.y;
        if (dx * dx + dy * dy <= r * r) {
          o.alive = false;
          final gen = b.generation + 1;
          caught++;
          maxGeneration = max(maxGeneration, gen);
          // Zanjir qanchalik uzun bo'lsa, shuncha ko'p ochko
          final points = 100 * gen;
          score += points;
          catches.add(Catch(o.x, o.y, points, gen, time));
          fresh.add(Blast(o.x, o.y, o.color, gen));
        }
      }
    }
    blasts
      ..removeWhere((b) => b.done)
      ..addAll(fresh);
  }
}
