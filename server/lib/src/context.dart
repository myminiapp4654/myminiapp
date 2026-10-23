import 'store.dart';

/// Har bir so'rov uchun: kim so'rayapti va ombor.
class Ctx {
  final Store db;
  final String uid;
  final String name;

  Ctx(this.db, this.uid, this.name);

  // ---- foydalanuvchi ma'lumotlari (yulduzlar, daraja) ----

  String get _userPath => 'users/$uid';

  Map<String, dynamic> get me => db.get(_userPath) ?? {'uid': uid};

  void addStars(String toUid, int count) {
    final path = 'users/$toUid';
    final u = db.get(path) ?? {'uid': toUid};
    u['stars'] = ((u['stars'] as int?) ?? 0) + count;
    db.set(path, u);
  }

  /// Bitta yulduz sarflaydi. Yetmasa false.
  bool spendStar() {
    final u = me;
    final stars = (u['stars'] as int?) ?? 0;
    if (stars <= 0) return false;
    u['stars'] = stars - 1;
    db.set(_userPath, u);
    return true;
  }

  int get wordPuzzleLevel => (me['wordPuzzleLevel'] as int?) ?? 0;

  void setWordPuzzleLevel(String toUid, int level) {
    final path = 'users/$toUid';
    final u = db.get(path) ?? {'uid': toUid};
    final current = (u['wordPuzzleLevel'] as int?) ?? 0;
    if (level <= current) return;
    u['wordPuzzleLevel'] = level;
    db.set(path, u);
  }
}

typedef Handler = Object? Function(Ctx c, Map<String, dynamic> p);

// ---- parametrlarni o'qish ----

String pStr(Map<String, dynamic> p, String key, {int maxLen = 200}) {
  final v = p[key];
  if (v is! String || v.isEmpty) throw GameError("Noto'g'ri so'rov ($key)");
  if (v.length > maxLen) throw GameError('Juda uzun matn');
  return v;
}

int pInt(Map<String, dynamic> p, String key, {int? min, int? max}) {
  final v = p[key];
  if (v is! int) throw GameError("Noto'g'ri so'rov ($key)");
  if ((min != null && v < min) || (max != null && v > max)) {
    throw GameError("Noto'g'ri qiymat ($key)");
  }
  return v;
}

String pCode(Map<String, dynamic> p, [String key = 'code']) =>
    pStr(p, key, maxLen: 6).toUpperCase();
