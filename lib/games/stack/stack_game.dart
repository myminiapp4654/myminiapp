import 'dart:math';

/// Stack — minora qurish.
///
/// Har qavatda yangi blok bir tomondan ikkinchisiga suzib yuradi (qavatlar
/// navbat bilan X va Z o'qi bo'ylab). Bosganingizda u to'xtaydi: pastdagi
/// blokdan chiqib turgan qismi kesilib tushadi, qolgani — yangi qavat.
/// Umuman tegmasa — o'yin tugaydi. Aniq ustiga qo'ysangiz ("Zo'r!") hech narsa
/// kesilmaydi, ketma-ket aniq qo'yishlar blokni biroz kattalashtiradi.
class StackBox {
  final double x, z, w, d;
  final int level;
  const StackBox(this.x, this.z, this.w, this.d, this.level);

  StackBox copyWith({double? x, double? z, double? w, double? d}) =>
      StackBox(x ?? this.x, z ?? this.z, w ?? this.w, d ?? this.d, level);
}

enum StackResult { placed, perfect, missed }

/// Kesilib tushgan bo'lak (ekranda qulab tushadi).
class StackPiece {
  final StackBox box;
  final double born;
  const StackPiece(this.box, this.born);
}

class StackGame {
  /// Asos blok o'lchami.
  static const base = 10.0;

  /// Suzish masofasi (markazdan har tomonga).
  static const range = 13.0;

  /// Shu farqdan kichik bo'lsa — "aniq" (kesilmaydi).
  static const perfectTolerance = 0.3;

  /// Ketma-ket aniq qo'yishdan keyin kattalashish.
  static const growAfter = 3;
  static const growBy = 0.5;

  final tower = <StackBox>[const StackBox(-base / 2, -base / 2, base, base, 0)];
  final pieces = <StackPiece>[];

  /// Hozir suzib yurgan blok va uning o'qdagi siljishi.
  late StackBox moving;
  double offset = -range;
  int direction = 1;

  bool over = false;
  int combo = 0;
  double time = 0;

  StackGame() {
    _spawn();
  }

  int get score => tower.length - 1;
  StackBox get top => tower.last;

  /// Shu qavatda blok X o'qi bo'ylab suzadimi (aks holda — Z).
  bool get alongX => (top.level + 1).isOdd;

  /// Tezlik (birlik/soniya): qavat sari oshib boradi.
  double get speed => min(9.0 + score * 0.35, 24.0);

  void _spawn() {
    final t = top;
    // Navbatdagi blok — bir tomondan chiqadi (har safar boshqa tomondan)
    direction = (t.level).isEven ? 1 : -1;
    offset = -range * direction;
    moving = _at(offset);
  }

  StackBox _at(double off) {
    final t = top;
    return alongX
        ? StackBox(t.x + off, t.z, t.w, t.d, t.level + 1)
        : StackBox(t.x, t.z + off, t.w, t.d, t.level + 1);
  }

  void update(double dt) {
    time += dt;
    pieces.removeWhere((p) => time - p.born > 2.5);
    if (over) return;
    offset += direction * speed * dt;
    if (offset > range) {
      offset = range - (offset - range);
      direction = -1;
    } else if (offset < -range) {
      offset = -range + (-range - offset);
      direction = 1;
    }
    moving = _at(offset);
  }

  /// Bosildi: blokni qo'yish.
  StackResult place() {
    if (over) return StackResult.missed;
    final t = top, m = moving;
    final x = alongX;
    final delta = x ? m.x - t.x : m.z - t.z;
    final size = x ? t.w : t.d;

    // Aniq — pastdagining ustiga to'g'ri o'tiradi
    if (delta.abs() <= perfectTolerance) {
      combo++;
      var box = x ? m.copyWith(x: t.x) : m.copyWith(z: t.z);
      if (combo >= growAfter) {
        // Seriya uchun mukofot: blok biroz kattalashadi (asosdan oshmaydi)
        if (x && box.w < base) {
          final g = min(growBy, base - box.w);
          box = box.copyWith(x: box.x - g / 2, w: box.w + g);
        } else if (!x && box.d < base) {
          final g = min(growBy, base - box.d);
          box = box.copyWith(z: box.z - g / 2, d: box.d + g);
        }
      }
      tower.add(box);
      _spawn();
      return StackResult.perfect;
    }

    combo = 0;
    final overlap = size - delta.abs();
    if (overlap <= 0) {
      over = true;
      pieces.add(StackPiece(m, time));
      return StackResult.missed;
    }

    // Kesish: qolgan qism — yangi qavat, chiqib turgani — qulaydi
    final StackBox kept, cut;
    if (x) {
      final start = delta > 0 ? m.x : t.x;
      kept = m.copyWith(x: start, w: overlap);
      cut = delta > 0
          ? m.copyWith(x: start + overlap, w: delta.abs())
          : m.copyWith(x: m.x, w: delta.abs());
    } else {
      final start = delta > 0 ? m.z : t.z;
      kept = m.copyWith(z: start, d: overlap);
      cut = delta > 0
          ? m.copyWith(z: start + overlap, d: delta.abs())
          : m.copyWith(z: m.z, d: delta.abs());
    }
    tower.add(kept);
    pieces.add(StackPiece(cut, time));
    _spawn();
    return StackResult.placed;
  }
}
