import 'dart:math';

/// Classic Ludo: 2–4 o'yinchi (odam yoki kompyuter), bitta telefonda.
///
/// Dona holati — "progress":
///   -1        uychada (qulflangan)
///   0..50     umumiy yo'lda (o'z boshlang'ich katagidan hisoblab)
///   51..55    o'z rangli yo'lagida (xavfsiz)
///   56        marrada
///
/// Qoidalar:
///  - uychadan chiqish uchun 6 kerak
///  - 6 tushsa — yana tashlaydi; ketma-ket uchinchi 6 — navbat yonadi
///  - raqib turgan katakka tushsa — raqib uychasiga qaytadi (+bonus yurish)
///  - boshlang'ich va yulduzli kataklar xavfsiz
///  - marraga aniq son bilan kiriladi; marraga yetsa — bonus yurish
///  - 4 ta donasini birinchi bo'lib marraga yetkazgan yutadi
const kLudoTrack = 52;
const kLudoHome = 56;

/// Ranglar: 0 qizil, 1 yashil, 2 sariq, 3 ko'k (soat yo'nalishida).
const kLudoStart = [0, 13, 26, 39];

/// Xavfsiz kataklar (umumiy yo'l bo'yicha): boshlang'ichlar va yulduzlar.
const kLudoSafe = {0, 8, 13, 21, 26, 34, 39, 47};

class LudoMove {
  final int token;
  final int from;
  final int to;

  /// Urilgan raqib donalari: (rang, dona).
  final List<(int, int)> captured;
  final bool reachedHome;

  const LudoMove(this.token, this.from, this.to,
      {this.captured = const [], this.reachedHome = false});
}

enum LudoPhase { roll, move, finished }

class LudoGame {
  /// O'yindagi ranglar (o'tirish tartibida).
  final List<int> colors;

  /// Kompyuter boshqaradigan ranglar.
  final Set<int> ai;

  /// tokens[rang][dona] — progress
  final tokens = List.generate(4, (_) => List.filled(4, -1));

  int _seat = 0;
  int? dice;
  int _sixes = 0;
  LudoPhase phase = LudoPhase.roll;
  int? winner;

  final Random _rnd;

  LudoGame({required this.colors, this.ai = const {}, Random? random})
      : _rnd = random ?? Random();

  /// 2 kishi — qarama-qarshi ranglar (qizil va sariq).
  static List<int> colorsFor(int players) => switch (players) {
        2 => [0, 2],
        3 => [0, 1, 2],
        _ => [0, 1, 2, 3],
      };

  int get current => colors[_seat];
  bool get isAiTurn => ai.contains(current);

  /// Umumiy yo'ldagi katak (faqat 0..50 progressda).
  static int globalOf(int color, int p) => (kLudoStart[color] + p) % kLudoTrack;

  bool _onTrack(int p) => p >= 0 && p <= 50;

  int homeCount(int color) => tokens[color].where((p) => p == kLudoHome).length;

  // ---------------------------------------------------------------- tosh

  /// Tosh tashlash. [value] — test uchun.
  int roll([int? value]) {
    if (phase != LudoPhase.roll) return dice ?? 0;
    final v = value ?? _rnd.nextInt(6) + 1;
    dice = v;
    if (v == 6) {
      _sixes++;
      if (_sixes == 3) {
        // Ketma-ket uchinchi 6 — navbat yonadi
        _nextSeat();
        return v;
      }
    }
    phase = legalTokens().isEmpty ? LudoPhase.roll : LudoPhase.move;
    if (phase == LudoPhase.roll) {
      // Yurish yo'q: 6 bo'lsa yana tashlaydi, aks holda navbat o'tadi
      if (v != 6) _nextSeat();
    }
    return v;
  }

  /// Hozirgi tosh bilan yura oladigan donalar.
  List<int> legalTokens() {
    final d = dice;
    if (d == null) return const [];
    return [
      for (var t = 0; t < 4; t++)
        if (_target(current, t, d) != null) t,
    ];
  }

  int? _target(int color, int t, int d) {
    final p = tokens[color][t];
    if (p == kLudoHome) return null;
    if (p == -1) return d == 6 ? 0 : null;
    final to = p + d;
    return to <= kLudoHome ? to : null; // marraga aniq son bilan
  }

  // ---------------------------------------------------------------- yurish

  LudoMove? move(int t) {
    if (phase != LudoPhase.move || !legalTokens().contains(t)) return null;
    final color = current;
    final from = tokens[color][t];
    final to = _target(color, t, dice!)!;
    tokens[color][t] = to;

    final captured = <(int, int)>[];
    if (_onTrack(to)) {
      final g = globalOf(color, to);
      if (!kLudoSafe.contains(g)) {
        for (final other in colors) {
          if (other == color) continue;
          for (var k = 0; k < 4; k++) {
            final op = tokens[other][k];
            if (_onTrack(op) && globalOf(other, op) == g) {
              tokens[other][k] = -1;
              captured.add((other, k));
            }
          }
        }
      }
    }
    final reachedHome = to == kLudoHome;

    if (homeCount(color) == 4) {
      winner = color;
      phase = LudoPhase.finished;
    } else if (dice == 6 || captured.isNotEmpty || reachedHome) {
      phase = LudoPhase.roll; // bonus yurish
      if (dice != 6) _sixes = 0;
    } else {
      _nextSeat();
    }
    return LudoMove(t, from, to, captured: captured, reachedHome: reachedHome);
  }

  void _nextSeat() {
    _seat = (_seat + 1) % colors.length;
    _sixes = 0;
    phase = LudoPhase.roll;
  }

  // ---------------------------------------------------------------- kompyuter

  /// Kompyuter uchun eng yaxshi dona.
  int? aiChoose() {
    final options = legalTokens();
    if (options.isEmpty) return null;
    final color = current;
    final d = dice!;

    double score(int t) {
      final p = tokens[color][t];
      final to = _target(color, t, d)!;
      var s = to.toDouble() * 0.1; // oldinga borganlar afzal
      if (to == kLudoHome) s += 50;
      if (p == -1) s += 30; // yangi dona chiqarish
      if (to > 50) s += 15; // xavfsiz yo'lakka kirish
      if (_onTrack(to)) {
        final g = globalOf(color, to);
        if (kLudoSafe.contains(g)) s += 8;
        if (!kLudoSafe.contains(g)) {
          for (final other in colors) {
            if (other == color) continue;
            for (final op in tokens[other]) {
              if (!_onTrack(op)) continue;
              final og = globalOf(other, op);
              if (og == g) s += 100; // urish
              // Orqasida 1..6 katak masofada raqib — xavf
              final behind = (g - og) % kLudoTrack;
              if (behind >= 1 && behind <= 6) s -= 12;
            }
          }
        }
      }
      // Hozir xavf ostida turgan donani qochirish
      if (_onTrack(p)) {
        final g = globalOf(color, p);
        if (!kLudoSafe.contains(g)) {
          for (final other in colors) {
            if (other == color) continue;
            for (final op in tokens[other]) {
              if (!_onTrack(op)) continue;
              final behind = (g - globalOf(other, op)) % kLudoTrack;
              if (behind >= 1 && behind <= 6) s += 10;
            }
          }
        }
      }
      return s;
    }

    options.sort((a, b) => score(b).compareTo(score(a)));
    return options.first;
  }
}

// ---------------------------------------------------------------- taxta

/// 15×15 taxtadagi umumiy yo'l kataklari (qator, ustun), qizil boshlanishidan.
const List<(int, int)> kLudoPath = [
  (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
  (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
  (0, 7),
  (0, 8), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
  (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
  (7, 14),
  (8, 14), (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
  (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8),
  (14, 7),
  (14, 6), (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
  (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
  (7, 0),
  (6, 0),
];

/// Har rangning marraga olib boruvchi yo'lagi (progress 51..55).
const List<List<(int, int)>> kLudoHomeLane = [
  [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
  [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
  [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
  [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
];

/// Uychadagi 4 ta joy.
const List<List<(double, double)>> kLudoYard = [
  [(1.5, 1.5), (1.5, 3.5), (3.5, 1.5), (3.5, 3.5)],
  [(1.5, 10.5), (1.5, 12.5), (3.5, 10.5), (3.5, 12.5)],
  [(10.5, 10.5), (10.5, 12.5), (12.5, 10.5), (12.5, 12.5)],
  [(10.5, 1.5), (10.5, 3.5), (12.5, 1.5), (12.5, 3.5)],
];

/// Marradagi joy (markaz, rangiga qarab biroz siljigan).
const List<(double, double)> kLudoFinish = [
  (7, 6.2), (6.2, 7), (7, 7.8), (7.8, 7),
];

/// Dona taxtada qayerda (qator, ustun) — o'rtasi.
(double, double) ludoCell(int color, int token, int p) {
  if (p == -1) {
    final y = kLudoYard[color][token];
    return (y.$1 + 0.0, y.$2 + 0.0);
  }
  if (p == kLudoHome) return kLudoFinish[color];
  if (p > 50) {
    final c = kLudoHomeLane[color][p - 51];
    return (c.$1 + 0.5, c.$2 + 0.5);
  }
  final c = kLudoPath[LudoGame.globalOf(color, p)];
  return (c.$1 + 0.5, c.$2 + 0.5);
}
