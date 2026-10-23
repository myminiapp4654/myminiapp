import 'store.dart';

/// Har bir so'rov uchun: kim so'rayapti va ombor.
class Ctx {
  final Store db;
  final String uid;
  final String name;

  Ctx(this.db, this.uid, this.name);
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
