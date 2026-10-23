import 'dart:math';
import 'dart:ui' show Offset;

/// Neon Snake: slither.io uslubidagi ilonlar.
///
/// - Dumaloq arena, ichida rangli ozuqa nuqtalari
/// - Ilonlar to'xtamay harakatlanadi, yo'nalishi silliq buriladi
/// - Ozuqa yeyilsa ilon uzayadi
/// - Ilon boshi boshqa ilon tanasiga (yoki arena chetiga) urilsa — o'ladi,
///   tanasi zanjirli portlab, yorqin ozuqaga aylanadi
/// - Eng uzun ilon — reyting boshida
///
/// Mantiq ekrandan mustaqil: keyinchalik serverda (onlayn) ham ishlatish mumkin.
class SnakeWorld {
  /// Arena radiusi (markaz — 0,0).
  static const radius = 1400.0;
  static const spacing = 8.0; // bo'g'imlar orasidagi masofa
  static const speed = 165.0; // birlik/soniya
  static const turnRate = 3.8; // radian/soniya
  static const foodTarget = 420;
  static const startLength = 14;

  final Random r;
  final int level;
  final snakes = <Snake>[];
  final food = <Food>[];

  /// Zanjirli portlashlar (ekranda ko'rsatish uchun).
  final bursts = <Burst>[];

  double time = 0;
  int _nextId = 0;

  /// O'lgan kompyuter ilonlari qaytadan paydo bo'lish vaqti.
  final _respawnAt = <double>[];

  static const botNames = [
    'Kobra', 'Piton', 'Chaqmoq', 'Shamol', 'Anakonda', 'Turbo',
    'Raketa', 'Yashin', 'Bo\'ron', 'Neon', 'Kamalak', 'Zilzila',
  ];

  SnakeWorld({this.level = 2, int? seed}) : r = Random(seed) {
    snakes.add(Snake(_nextId++, 'Siz', 0, isPlayer: true, start: const Offset(0, 0), angle: -pi / 2));
    for (var k = 0; k < botCount; k++) {
      _spawnBot();
    }
    while (food.length < foodTarget) {
      _spawnFood();
    }
  }

  int get botCount => switch (level) { 1 => 6, 2 => 8, _ => 10 };

  Snake get player => snakes.first;

  /// O'yinchining yo'nalishini o'zgartirish (joystik).
  void steer(double angle) => player.targetAngle = angle;

  // ---------------------------------------------------------------- paydo bo'lish

  Offset _randomPoint(double margin) {
    final a = r.nextDouble() * 2 * pi;
    final d = sqrt(r.nextDouble()) * (radius - margin);
    return Offset(cos(a) * d, sin(a) * d);
  }

  void _spawnFood() {
    food.add(Food(_randomPoint(30), 1, r.nextInt(Snake.palette.length), time));
  }

  void _spawnBot() {
    // Boshqa ilonlardan (butun tanasidan) va o'yinchidan uzoq joy
    var pos = _randomPoint(250);
    var angle = r.nextDouble() * 2 * pi;
    final length = startLength + r.nextInt(level * 18 + 10);
    for (var k = 0; k < 40; k++) {
      final p = _randomPoint(250);
      final a = r.nextDouble() * 2 * pi;
      final body = [
        for (var i = 0; i < length; i += 3) p - Offset(cos(a), sin(a)) * (i * spacing),
      ];
      final safe = snakes.every((o) {
        if (!o.alive) return true;
        if (o.isPlayer && body.any((q) => (q - o.head).distance < 400)) return false;
        for (final q in body) {
          for (var i = 0; i < o.segs.length; i += 2) {
            if ((o.segs[i] - q).distance < 150) return false;
          }
        }
        return true;
      });
      if (safe && body.every((q) => q.distance < radius - 60)) {
        pos = p;
        angle = a;
        break;
      }
    }
    snakes.add(Snake(
      _nextId++,
      botNames[(_nextId - 1) % botNames.length],
      1 + r.nextInt(Snake.palette.length - 1),
      start: pos,
      angle: angle,
      length: length,
    ));
  }

  // ---------------------------------------------------------------- kadr

  /// Bir kadr (dt soniyada, katta qadamlar mayda qismlarga bo'linadi).
  void update(double dt) {
    var left = dt.clamp(0.0, 0.1);
    while (left > 0) {
      final step = min(left, 1 / 60);
      _step(step);
      left -= step;
    }
  }

  void _step(double dt) {
    time += dt;
    for (final s in snakes) {
      if (!s.alive) continue;
      if (!s.isPlayer) _think(s, dt);
      s.move(dt);
    }
    _eat();
    _collide();

    // O'lgan kompyuterlar o'rniga yangilari
    snakes.removeWhere((s) => !s.alive && !s.isPlayer);
    final bots = snakes.where((s) => !s.isPlayer).length + _respawnAt.length;
    for (var k = bots; k < botCount; k++) {
      _respawnAt.add(time + 2.5);
    }
    _respawnAt.removeWhere((t) {
      if (t > time) return false;
      _spawnBot();
      return true;
    });
    while (food.where((f) => !f.fromDeath).length < foodTarget) {
      _spawnFood();
    }
    // O'lim ozuqasi asta yo'qoladi
    food.removeWhere((f) => f.fromDeath && time - f.born > 25);
    bursts.removeWhere((b) => time - b.start > b.duration);
  }

  void _eat() {
    for (final s in snakes) {
      if (!s.alive) continue;
      final reach = s.radius + 8;
      food.removeWhere((f) {
        if (f.born > time) return false; // portlash hali yetib kelmagan
        final d = f.pos - s.head;
        if (d.dx.abs() > reach || d.dy.abs() > reach || d.distance > reach) return false;
        s.feed(f.value);
        return true;
      });
    }
  }

  void _collide() {
    final dead = <Snake>[];
    for (final a in snakes) {
      if (!a.alive) continue;
      // Arena cheti
      if (a.head.distance > radius - a.radius) {
        dead.add(a);
        continue;
      }
      for (final b in snakes) {
        if (b == a || !b.alive) continue;
        // Tez tekshiruv: ilonlar umuman yaqinmi
        if ((b.head - a.head).distance > b.segs.length * spacing + 60) continue;
        final hit = a.radius + b.radius * 0.85;
        if (b.segs.any((p) => (p - a.head).distance < hit)) {
          dead.add(a);
          b.kills++;
          break;
        }
      }
    }
    for (final s in dead) {
      kill(s);
    }
  }

  /// Ilon o'ladi: tanasi zanjirli portlab, ozuqaga aylanadi.
  void kill(Snake s) {
    if (!s.alive) return;
    s.alive = false;
    s.diedAt = time;
    bursts.add(Burst(List.of(s.segs), s.color, time));
    for (var k = 0; k < s.segs.length; k += 2) {
      final jitter = Offset(r.nextDouble() * 12 - 6, r.nextDouble() * 12 - 6);
      var p = s.segs[k] + jitter;
      if (p.distance > radius - 20) p = p / p.distance * (radius - 20);
      food.add(Food(p, 2, s.color, time + k * Burst.delay, fromDeath: true));
    }
  }

  // ---------------------------------------------------------------- kompyuter

  /// Nuqtada xavf bormi (arena cheti yoki boshqa ilon tanasi).
  bool _danger(Snake self, Offset p, double margin) {
    if (p.distance > radius - margin) return true;
    for (final o in snakes) {
      if (o == self || !o.alive) continue;
      if ((o.head - p).distance > o.segs.length * spacing + margin + 40) continue;
      final hit = self.radius + o.radius + margin * 0.5;
      for (final q in o.segs) {
        if ((q - p).dx.abs() < hit && (q - p).dy.abs() < hit && (q - p).distance < hit) return true;
      }
    }
    return false;
  }

  bool _dangerAlong(Snake s, double angle, double reach) {
    for (final d in [reach * 0.35, reach * 0.7, reach]) {
      if (_danger(s, s.head + Offset(cos(angle), sin(angle)) * d, 18)) return true;
    }
    return false;
  }

  void _think(Snake s, double dt) {
    s.thinkIn -= dt;
    if (s.thinkIn > 0) return;
    s.thinkIn = switch (level) { 1 => 0.32, 2 => 0.18, _ => 0.1 } * (0.8 + r.nextDouble() * 0.4);
    final reach = switch (level) { 1 => 70.0, 2 => 110.0, _ => 150.0 };

    // 1. Xavfdan qochish (oson kompyuter ba'zan e'tibor bermaydi)
    final careless = level == 1 && r.nextDouble() < 0.25;
    if (!careless && _dangerAlong(s, s.angle, reach)) {
      for (final turn in const [0.6, -0.6, 1.2, -1.2, 1.9, -1.9, 2.6, -2.6]) {
        final side = r.nextBool() ? turn : -turn;
        if (!_dangerAlong(s, s.angle + side, reach)) {
          s.targetAngle = s.angle + side;
          return;
        }
      }
      s.targetAngle = s.angle + pi; // hamma tomon xavfli — orqaga
      return;
    }

    // 2. Qiyin kompyuter o'yinchining yo'lini to'sishga urinadi
    final p = player;
    if (level >= 3 && time > 6 && p.alive && s.segs.length > p.segs.length * 0.7) {
      final d = (p.head - s.head).distance;
      if (d < 320 && r.nextDouble() < 0.6) {
        final ahead = p.head + Offset(cos(p.angle), sin(p.angle)) * 110;
        s.targetAngle = atan2(ahead.dy - s.head.dy, ahead.dx - s.head.dx);
        return;
      }
    }

    // 3. Eng foydali ozuqaga
    Food? best;
    var bestScore = 0.0;
    for (final f in food) {
      final d = (f.pos - s.head).distance;
      if (d > 420) continue;
      final score = f.value / (d + 30);
      if (score > bestScore) {
        bestScore = score;
        best = f;
      }
    }
    if (best != null) {
      s.targetAngle = atan2(best.pos.dy - s.head.dy, best.pos.dx - s.head.dx);
    } else if (r.nextDouble() < 0.1) {
      s.targetAngle = s.angle + (r.nextDouble() - 0.5) * 1.5;
    }
    // Markazdan juda uzoqlashmaslik
    if (s.head.distance > radius * 0.8 && r.nextDouble() < 0.3) {
      s.targetAngle = atan2(-s.head.dy, -s.head.dx);
    }
  }

  // ---------------------------------------------------------------- reyting

  /// Tirik ilonlar uzunligi bo'yicha.
  List<Snake> get leaderboard =>
      snakes.where((s) => s.alive).toList()..sort((a, b) => b.length.compareTo(a.length));

  /// O'yinchining o'rni (1 dan).
  int get playerRank => leaderboard.indexOf(player) + 1;
}

class Snake {
  static const palette = [
    0xFF00F5FF, // moviy (o'yinchi)
    0xFFFF2E97,
    0xFFB4FF39,
    0xFFFFE53B,
    0xFFFF8C1A,
    0xFFB967FF,
    0xFF39FFB0,
    0xFFFF4D4D,
  ];

  final int id;
  final String name;
  final int color; // palette indeksi
  final bool isPlayer;

  /// Bo'g'imlar: [0] — bosh.
  final List<Offset> segs;
  double angle;
  double targetAngle;
  double _grow = 0;
  bool alive = true;
  double diedAt = 0;
  int kills = 0;
  double thinkIn = 0;

  Snake(this.id, this.name, this.color,
      {this.isPlayer = false, required Offset start, required this.angle, int length = SnakeWorld.startLength})
      : targetAngle = angle,
        segs = [
          for (var k = 0; k < length; k++) start - Offset(cos(angle), sin(angle)) * (k * SnakeWorld.spacing),
        ];

  Offset get head => segs.first;
  int get length => segs.length;

  /// Kattalashgan sari biroz yo'g'onlashadi.
  double get radius => 7 + min(9.0, segs.length * 0.035);

  void feed(double value) => _grow += value * 0.6;

  void move(double dt) {
    // Yo'nalishni silliq burish (eng qisqa tomonga)
    var diff = (targetAngle - angle) % (2 * pi);
    if (diff > pi) diff -= 2 * pi;
    final maxTurn = SnakeWorld.turnRate * dt * (1.0 - min(0.4, segs.length / 900));
    angle += diff.clamp(-maxTurn, maxTurn);

    final step = Offset(cos(angle), sin(angle)) * (SnakeWorld.speed * dt);
    segs[0] = segs[0] + step;
    // Har bir bo'g'im oldingisiga ergashadi
    for (var k = 1; k < segs.length; k++) {
      final d = segs[k] - segs[k - 1];
      final len = d.distance;
      if (len > SnakeWorld.spacing) {
        segs[k] = segs[k - 1] + d / len * SnakeWorld.spacing;
      }
    }
    while (_grow >= 1) {
      _grow -= 1;
      segs.add(segs.last);
    }
  }
}

class Food {
  final Offset pos;
  final double value;
  final int color;
  final double born;
  final bool fromDeath;
  Food(this.pos, this.value, this.color, this.born, {this.fromDeath = false});
}

/// O'lgan ilon tanasi bo'ylab boshdan dumga yuguradigan portlash.
class Burst {
  static const delay = 0.012; // har bir bo'g'im orasida
  static const ring = 0.4; // bitta halqa davomiyligi

  final List<Offset> points;
  final int color;
  final double start;
  Burst(this.points, this.color, this.start);

  double get duration => points.length * delay + ring;
}
