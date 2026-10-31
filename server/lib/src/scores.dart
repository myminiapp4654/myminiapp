import 'context.dart';
import 'store.dart';

/// Rekordlar jadvali bor o'yinlar.
const kScoreGames = {'stack', 'knife'};

/// Jadvalda saqlanadigan o'rinlar soni.
const kScoreTop = 50;

/// Rekordlar: har bir o'yinchining eng yaxshi natijasi, kamayish tartibida.
///
/// Hujjat: `scores/<o'yin>` = {top: [{uid, name, score, at}, ...]}.
/// Mijoz o'yin tugaganda (va ilova ochilganda — telefonda saqlangan
/// rekordini) yuboradi, shuning uchun server qayta ishga tushsa ham
/// jadval o'yinchilar o'ynagan sari o'zi tiklanadi.
Map<String, Handler> scoreHandlers() => {
      'score.submit': _submit,
    };

Object? _submit(Ctx c, Map<String, dynamic> p) {
  final game = pStr(p, 'game', maxLen: 20);
  if (!kScoreGames.contains(game)) throw GameError("Noma'lum o'yin");
  final score = pInt(p, 'score', min: 0, max: 100000);

  final path = 'scores/$game';
  final top = [
    for (final e in (c.db.get(path)?['top'] as List? ?? const []))
      Map<String, dynamic>.from(e as Map),
  ];
  final mine = top.indexWhere((e) => e['uid'] == c.uid);
  if (mine >= 0) {
    final old = top[mine]['score'] as int;
    if (old >= score) {
      // Rekord o'zgarmadi, lekin ism yangilangan bo'lishi mumkin
      if (top[mine]['name'] != c.name) {
        top[mine]['name'] = c.name;
        c.db.set(path, {'top': top});
      }
      return {'rank': mine + 1, 'best': old};
    }
    top.removeAt(mine);
  }
  if (score == 0) return {'rank': null, 'best': 0};

  top.add({
    'uid': c.uid,
    'name': c.name,
    'score': score,
    'at': DateTime.now().millisecondsSinceEpoch,
  });
  // Ko'p ochko oldinda; teng bo'lsa — kim oldin erishgan
  top.sort((a, b) {
    final s = (b['score'] as int).compareTo(a['score'] as int);
    return s != 0 ? s : (a['at'] as int).compareTo(b['at'] as int);
  });
  if (top.length > kScoreTop) top.removeRange(kScoreTop, top.length);
  c.db.set(path, {'top': top});
  final rank = top.indexWhere((e) => e['uid'] == c.uid);
  return {'rank': rank < 0 ? null : rank + 1, 'best': score};
}
