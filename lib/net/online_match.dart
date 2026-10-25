import 'package:flutter/foundation.dart';

/// Onlayn o'yindagi bitta raund bilan aloqa: o'yin ekrani shu orqali
/// yurishlarni yuboradi va raqib yurishlarini oladi.
///
/// Navbatli o'yinlarda (Shaxmat, Shashka) [moves] — boshidan beri barcha
/// yurishlar ro'yxati. Ekran o'zi qo'llagan yurishlar sonini eslab qoladi va
/// faqat yangilarini qo'llaydi — shuning uchun ilova qayta ochilsa ham o'yin tiklanadi.
class OnlineMatch {
  final String code;
  final String myUid;

  /// O'yinchilar kirgan tartibida: (uid, ism).
  final List<(String, String)> players;

  /// Birinchi yuruvchi (Shaxmatda oq).
  final String first;

  /// Umumiy tasodif urug'i (jonli o'yinlar uchun).
  final int seed;

  /// O'yin boshlanishigacha soniyalar.
  final double countdown;

  final ValueListenable<List<String>> moves;

  /// O'yindan chiqib ketgan o'yinchi (bo'lsa).
  final ValueListenable<String?> left;

  final void Function(String move) send;
  final VoidCallback end;
  final VoidCallback again;

  /// Jonli o'yinlar (Neon Snake): o'z holatini yuborish va boshqalarnikini kuzatish.
  final void Function(Map<String, dynamic> state)? sendState;
  final Stream<Map<String, dynamic>?> Function(String uid)? watchState;

  OnlineMatch({
    required this.code,
    required this.myUid,
    required this.players,
    required this.first,
    required this.seed,
    required this.countdown,
    required this.moves,
    required this.left,
    required this.send,
    required this.end,
    required this.again,
    this.sendState,
    this.watchState,
  });

  bool get iAmFirst => first == myUid;

  String nameOf(String uid) =>
      players.firstWhere((p) => p.$1 == uid, orElse: () => (uid, "O'yinchi")).$2;

  /// Ikki kishilik o'yinda raqib.
  String get opponent => players.firstWhere((p) => p.$1 != myUid, orElse: () => ('', 'Raqib')).$1;
}
