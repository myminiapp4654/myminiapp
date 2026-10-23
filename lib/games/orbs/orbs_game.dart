import 'dart:math';

/// Chain Burst: Sharlar — fizikali boshqotirma (bir kishilik).
///
/// - Sharlar og'irlik kuchi bilan bir-birining ustiga to'planib turadi
/// - Sharni bossangiz, unga tegib turgan bir xil rangdagi sharlar zanjir bo'lib portlaydi
/// - Portlash to'lqini atrofdagi sharlarni itaradi — ular uchadi, qulaydi, joylashuv o'zgaradi
/// - Bomba (qora shar) to'lqinga tegsa portlaydi va atrofidagi hamma rangni olib ketadi,
///   boshqa bombalarni ham yoqib zanjirni davom ettiradi
/// - Har darajada vazifa va cheklangan yurishlar; qolgan yurishlarga qarab yulduz
class Orb {
  double x, y;
  double vx = 0, vy = 0;
  final int color; // [OrbsGame.bomb] — bomba
  bool alive = true;

  Orb(this.x, this.y, this.color);

  bool get isBomb => color == OrbsGame.bomb;
}

/// Portlash ko'rinishi (ekranda kengayib so'nadigan halqa).
class BurstFx {
  final double x, y;
  final int color;
  double age = 0;
  BurstFx(this.x, this.y, this.color);
}

class _Pending {
  final int index;
  final double at;
  _Pending(this.index, this.at);
}

class OrbsGoal {
  /// null — istalgan rang
  final int? color;
  final int target;
  const OrbsGoal(this.color, this.target);
}

enum OrbsResult { playing, won, lost }

class OrbsGame {
  static const width = 9.0;
  static const height = 14.0;
  static const radius = 0.5;
  static const bomb = -1;
  static const _gravity = 28.0;
  static const _substep = 1 / 240;

  final int level;
  late final List<Orb> orbs;
  late int moves;
  late final int startMoves;
  late final OrbsGoal goal;
  late final int colors;

  int progress = 0;
  double time = 0;
  final bursts = <BurstFx>[];
  final _pending = <_Pending>[];
  double _still = 0;

  OrbsGame(this.level) {
    _generate();
  }

  // ---------------------------------------------------------------- daraja

  void _generate() {
    final rnd = Random(level * 7919 + 13);
    colors = min(5, 3 + (level - 1) ~/ 3);
    final n = min(72, 40 + level * 2);
    final bombs = min(4, level ~/ 2);

    // Asal katakdek zich joylashtirish, pastdan yuqoriga
    final positions = <(double, double)>[];
    final rowH = sqrt(3) * radius;
    for (var row = 0; positions.length < n; row++) {
      final odd = row.isOdd;
      final perRow = odd ? 8 : 9;
      for (var c = 0; c < perRow && positions.length < n; c++) {
        final x = radius + (odd ? radius : 0) + c * 2 * radius;
        final y = height - radius - row * rowH;
        positions.add((x + (rnd.nextDouble() - 0.5) * 0.02, y));
      }
    }

    // Ranglar: qo'shnisining rangini olish ehtimoli — guruhlar paydo bo'ladi
    orbs = [];
    for (final (x, y) in positions) {
      int color = rnd.nextInt(colors);
      if (orbs.isNotEmpty && rnd.nextDouble() < 0.45) {
        final near = orbs
            .where((o) => _dist(o.x, o.y, x, y) < 2.2 * radius)
            .toList();
        if (near.isNotEmpty) color = near[rnd.nextInt(near.length)].color;
      }
      orbs.add(Orb(x, y, color));
    }
    // Bombalar o'rta qatlamlarga
    for (var k = 0; k < bombs; k++) {
      final i = n ~/ 4 + rnd.nextInt(n ~/ 2);
      orbs[i] = Orb(orbs[i].x, orbs[i].y, bomb);
    }

    // Vazifa: toq darajalar — istalgan sharlar, juftlari — bitta rang
    if (level.isOdd) {
      goal = OrbsGoal(null, (n * (0.45 + min(0.25, level * 0.01))).round());
    } else {
      final counts = List.filled(colors, 0);
      for (final o in orbs) {
        if (!o.isBomb) counts[o.color]++;
      }
      final c = rnd.nextInt(colors);
      goal = OrbsGoal(c, counts[c]);
    }
    startMoves = moves = level <= 2 ? 8 : max(4, 9 - level ~/ 3);

    // Boshlanishda tinch turishi uchun
    for (var k = 0; k < 240; k++) {
      _physics(_substep * 4);
    }
    for (final o in orbs) {
      o.vx = o.vy = 0;
    }
  }

  // ---------------------------------------------------------------- holat

  int get aliveCount => orbs.where((o) => o.alive).length;
  bool get goalReached => progress >= goal.target;

  /// Portlashlar tugadi va sharlar tinchlandi.
  bool get settled => _pending.isEmpty && _still >= 0.25;

  OrbsResult get result {
    if (goalReached) return OrbsResult.won;
    if (moves <= 0 && settled) return OrbsResult.lost;
    return OrbsResult.playing;
  }

  int get stars {
    if (!goalReached) return 0;
    if (moves >= 2) return 3;
    if (moves == 1) return 2;
    return 1;
  }

  static double _dist(double x1, double y1, double x2, double y2) =>
      sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

  int? orbAt(double x, double y) {
    for (var i = 0; i < orbs.length; i++) {
      final o = orbs[i];
      if (o.alive && _dist(o.x, o.y, x, y) <= radius * 1.05) return i;
    }
    return null;
  }

  /// [i] ga tegib turgan bir xil rangdagi sharlar (BFS) va ularning chuqurligi.
  Map<int, int> cluster(int i) {
    final start = orbs[i];
    final depth = {i: 0};
    if (start.isBomb) return depth;
    final queue = [i];
    while (queue.isNotEmpty) {
      final k = queue.removeAt(0);
      final a = orbs[k];
      for (var j = 0; j < orbs.length; j++) {
        if (depth.containsKey(j)) continue;
        final b = orbs[j];
        if (!b.alive || b.color != start.color) continue;
        if (_dist(a.x, a.y, b.x, b.y) <= 2 * radius + 0.12) {
          depth[j] = depth[k]! + 1;
          queue.add(j);
        }
      }
    }
    return depth;
  }

  // ---------------------------------------------------------------- yurish

  /// Sharni bosish. Yurish sarflansa true.
  bool tap(double x, double y) {
    if (result != OrbsResult.playing || moves <= 0) return false;
    if (_pending.isNotEmpty) return false; // oldingi zanjir tugashini kutamiz
    final i = orbAt(x, y);
    if (i == null) return false;
    moves--;
    _still = 0;
    // Guruh to'lqinsimon portlaydi: yaqinlari oldin
    cluster(i).forEach((k, d) => _pending.add(_Pending(k, time + d * 0.045)));
    return true;
  }

  void _burst(int i) {
    final o = orbs[i];
    if (!o.alive) return;
    o.alive = false;
    bursts.add(BurstFx(o.x, o.y, o.color));
    if (!o.isBomb && (goal.color == null || goal.color == o.color)) {
      progress++;
    }

    final shock = o.isBomb ? 2.4 : 1.6;
    final power = o.isBomb ? 22.0 : 7.0;
    for (var j = 0; j < orbs.length; j++) {
      final b = orbs[j];
      if (!b.alive) continue;
      final d = _dist(o.x, o.y, b.x, b.y);
      if (d > shock || d < 1e-6) continue;
      final f = power * (1 - d / shock);
      b.vx += (b.x - o.x) / d * f;
      b.vy += (b.y - o.y) / d * f - f * 0.3; // biroz yuqoriga otiladi
      _still = 0;

      final queued = _pending.any((p) => p.index == j);
      if (queued) continue;
      // Bomba to'lqinga tegsa — o'zi ham portlaydi (zanjir)
      if (b.isBomb && d <= 1.7) {
        _pending.add(_Pending(j, time + 0.12));
      } else if (o.isBomb && d <= 1.7) {
        // Bomba atrofidagi hamma rang portlaydi
        _pending.add(_Pending(j, time + 0.05 + d * 0.03));
      }
    }
  }

  // ---------------------------------------------------------------- fizika

  /// Vaqtni [dt] soniyaga oldinga suradi.
  void update(double dt) {
    final before = [for (final o in orbs) (o.x, o.y)];
    var left = min(dt, 1 / 20);
    while (left > 1e-9) {
      final h = min(_substep, left);
      time += h;
      _pending.sort((a, b) => a.at.compareTo(b.at));
      while (_pending.isNotEmpty && _pending.first.at <= time) {
        _burst(_pending.removeAt(0).index);
      }
      _physics(h);
      left -= h;
    }
    for (final b in bursts) {
      b.age += dt;
    }
    bursts.removeWhere((b) => b.age > 0.45);

    // Tinchlik — sharlar amalda siljimayapti (tezlik emas, siljish bo'yicha:
    // ustma-ust turgan sharlarda tezlik titrab turadi, joyi esa o'zgarmaydi)
    var maxMove = 0.0;
    for (var k = 0; k < orbs.length; k++) {
      if (!orbs[k].alive) continue;
      maxMove = max(
        maxMove,
        _dist(orbs[k].x, orbs[k].y, before[k].$1, before[k].$2),
      );
    }
    final moving = maxMove > 0.25 * dt;
    _still = moving ? 0 : _still + dt;
  }

  void _physics(double h) {
    final alive = [
      for (final o in orbs)
        if (o.alive) o,
    ];
    for (final o in alive) {
      o.vy += _gravity * h;
      o.vx *= 0.9995;
      o.x += o.vx * h;
      o.y += o.vy * h;
      _walls(o);
    }
    // To'qnashuv va chegaralar navbatma-navbat: ustma-ust sharlar
    // og'irlikdan bir-biriga botib ketmasligi uchun bir necha marta
    for (var pass = 0; pass < 4; pass++) {
      _collide(alive);
      for (final o in alive) {
        _walls(o);
      }
    }
  }

  void _walls(Orb o) {
    if (o.x < radius) {
      o.x = radius;
      o.vx = -o.vx * 0.3;
    } else if (o.x > width - radius) {
      o.x = width - radius;
      o.vx = -o.vx * 0.3;
    }
    if (o.y > height - radius) {
      o.y = height - radius;
      o.vy = -o.vy * 0.2;
      o.vx *= 0.9;
    }
    if (o.y < -height) o.y = -height;
  }

  void _collide(List<Orb> alive) {
    const minD = 2 * radius;
    {
      for (var a = 0; a < alive.length; a++) {
        final p = alive[a];
        for (var b = a + 1; b < alive.length; b++) {
          final q = alive[b];
          final dx = q.x - p.x, dy = q.y - p.y;
          if (dx.abs() >= minD || dy.abs() >= minD) continue;
          final d2 = dx * dx + dy * dy;
          if (d2 >= minD * minD || d2 < 1e-12) continue;
          final d = sqrt(d2);
          final nx = dx / d, ny = dy / d;
          final push = (minD - d) / 2;
          p.x -= nx * push;
          p.y -= ny * push;
          q.x += nx * push;
          q.y += ny * push;
          final vn = (q.vx - p.vx) * nx + (q.vy - p.vy) * ny;
          if (vn < 0) {
            final j = -(1 + 0.15) * vn / 2;
            p.vx -= j * nx;
            p.vy -= j * ny;
            q.vx += j * nx;
            q.vy += j * ny;
          }
        }
      }
    }
  }
}
