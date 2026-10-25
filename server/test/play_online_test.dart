import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

void main() {
  final h = playHandlers({'111'});
  Object? call(Store db, String uid, String m, [Map<String, dynamic> p = const {}]) =>
      h[m]!(Ctx(db, uid, 'N$uid'), p);

  test("shaxmat xonasi: istalgan foydalanuvchi ochadi, navbat tekshiriladi, ranglar almashadi", () {
    final db = Store();
    // Istalgan foydalanuvchi xona ocha oladi
    expect((call(db, 'tg2', 'play.create', {'game': 'chess'}) as Map)['code'], isA<String>());
    expect(() => call(db, 'tg2', 'play.create', {'game': 'tetris'}), throwsA(isA<GameError>()));
    final code = (call(db, 'tg111', 'play.create', {'game': 'chess'}) as Map)['code'] as String;
    call(db, 'tg2', 'play.join', {'code': code});
    expect(() => call(db, 'tg3', 'play.join', {'code': code}), throwsA(isA<GameError>())); // 2 kishilik
    call(db, 'tg111', 'play.ready', {'code': code, 'ready': true});
    call(db, 'tg2', 'play.ready', {'code': code, 'ready': true});
    var d = db.get('play/$code')!;
    expect(d['state'], 'playing');
    expect(d['first'], 'tg111');

    expect(() => call(db, 'tg2', 'play.move', {'code': code, 'm': 'e7e5'}), throwsA(isA<GameError>()));
    call(db, 'tg111', 'play.move', {'code': code, 'm': 'e2e4'});
    expect(() => call(db, 'tg111', 'play.move', {'code': code, 'm': 'd2d4'}), throwsA(isA<GameError>()));
    call(db, 'tg2', 'play.move', {'code': code, 'm': 'e7e5'});
    expect(db.get('play/$code')!['moves'], ['e2e4', 'e7e5']);

    call(db, 'tg2', 'play.end', {'code': code});
    call(db, 'tg2', 'play.again', {'code': code});
    call(db, 'tg111', 'play.ready', {'code': code, 'ready': true});
    call(db, 'tg2', 'play.ready', {'code': code, 'ready': true});
    d = db.get('play/$code')!;
    expect(d['first'], 'tg2'); // 2-raundda ikkinchi o'yinchi oq
    expect(d['moves'], isEmpty);
    db.dispose();
  });

  test("o'yin paytida chiqib ketsa — tugaydi; snake holati alohida hujjatda", () {
    final db = Store();
    final code = (call(db, 'tg111', 'play.create', {'game': 'snake'}) as Map)['code'] as String;
    for (final u in ['tg2', 'tg3']) {
      call(db, u, 'play.join', {'code': code});
    }
    for (final u in ['tg111', 'tg2', 'tg3']) {
      call(db, u, 'play.ready', {'code': code, 'ready': true});
    }
    expect(db.get('play/$code')!['state'], 'playing');
    call(db, 'tg2', 'play.state', {'code': code, 's': {'x': 1}});
    expect(db.get('pst/$code/tg2'), {'x': 1});
    call(db, 'tg2', 'play.leave', {'code': code});
    expect(db.get('pst/$code/tg2'), isNull);
    expect(db.get('play/$code')!['state'], 'playing'); // 2 kishi qoldi — davom etadi
    call(db, 'tg3', 'play.leave', {'code': code});
    expect(db.get('play/$code')!['state'], 'done');
    db.dispose();
  });
}
