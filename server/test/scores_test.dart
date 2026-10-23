import 'dart:io';

import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

void main() {
  final submit = scoreHandlers()['score.submit']!;

  test("rekordlar: eng yaxshisi saqlanadi, tartib to'g'ri, pasaymaydi", () {
    final db = Store();
    expect(submit(Ctx(db, 'a', 'Ali'), {'game': 'stack', 'score': 12}), {'rank': 1, 'best': 12});
    expect(submit(Ctx(db, 'b', 'Vali'), {'game': 'stack', 'score': 30}), {'rank': 1, 'best': 30});
    // Alining yomonroq natijasi rekordni tushirmaydi
    expect(submit(Ctx(db, 'a', 'Ali'), {'game': 'stack', 'score': 5}), {'rank': 2, 'best': 12});
    // Yaxshiroq natija — yuqoriga ko'tariladi
    expect(submit(Ctx(db, 'a', 'Ali Valiyev'), {'game': 'stack', 'score': 40}), {'rank': 1, 'best': 40});
    final top = db.get('scores/stack')!['top'] as List;
    expect(top.map((e) => e['name']), ['Ali Valiyev', 'Vali']);
    expect(top.length, 2);
    db.dispose();
  });

  test("noto'g'ri so'rovlar rad etiladi", () {
    final db = Store();
    expect(() => submit(Ctx(db, 'a', 'A'), {'game': 'chess', 'score': 5}), throwsA(isA<GameError>()));
    expect(() => submit(Ctx(db, 'a', 'A'), {'game': 'stack', 'score': -1}), throwsA(isA<GameError>()));
    expect(() => submit(Ctx(db, 'a', 'A'), {'game': 'stack', 'score': 'x'}), throwsA(isA<GameError>()));
    db.dispose();
  });

  test("jadval faylga saqlanadi va qayta yuklanadi", () {
    final dir = Directory.systemTemp.createTempSync('scores');
    final db = Store(dataDir: dir.path);
    submit(Ctx(db, 'a', 'Ali'), {'game': 'stack', 'score': 7});
    db.dispose(); // saqlaydi
    final again = Store(dataDir: dir.path);
    expect((again.get('scores/stack')!['top'] as List).single['score'], 7);
    again.dispose();
    dir.deleteSync(recursive: true);
  });
}
