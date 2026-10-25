import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

void main() {
  final h = stackHandlers({'111'});
  Object? call(Store db, String uid, String m, [Map<String, dynamic> p = const {}]) =>
      h[m]!(Ctx(db, uid, 'N$uid'), p);

  test("xonani istalgan foydalanuvchi ochadi, do'stlar havola bilan kiradi, hamma tayyor — boshlanadi", () {
    final db = Store();
    expect((call(db, 'tg222', 'stack.create') as Map)['code'], isA<String>());
    final code = (call(db, 'tg111', 'stack.create') as Map)['code'] as String;
    call(db, 'tg222', 'stack.join', {'code': code});
    var d = db.get('stack/$code')!;
    expect((d['players'] as Map).length, 2);
    expect(d['state'], 'lobby');

    call(db, 'tg111', 'stack.ready', {'code': code, 'ready': true});
    expect(db.get('stack/$code')!['state'], 'lobby'); // bittasi hali tayyor emas
    call(db, 'tg222', 'stack.ready', {'code': code, 'ready': true});
    d = db.get('stack/$code')!;
    expect(d['state'], 'playing');
    expect((d['startAt'] as int) - (d['serverNow'] as int), 3000);

    // Yurishlar tarqatiladi
    call(db, 'tg222', 'stack.place', {'code': code, 'offset': 1.25});
    call(db, 'tg222', 'stack.place', {'code': code, 'offset': -0.5});
    d = db.get('stack/$code')!;
    expect((d['players'] as Map)['tg222']['moves'], [1.25, -0.5]);

    // Boshlangan o'yinga begona kira olmaydi
    expect(() => call(db, 'tg333', 'stack.join', {'code': code}), throwsA(isA<GameError>()));

    // Hamma yiqildi — tugadi; yana o'ynash — lobbiga
    call(db, 'tg111', 'stack.over', {'code': code});
    expect(db.get('stack/$code')!['state'], 'playing');
    call(db, 'tg222', 'stack.over', {'code': code});
    expect(db.get('stack/$code')!['state'], 'done');
    call(db, 'tg222', 'stack.again', {'code': code});
    d = db.get('stack/$code')!;
    expect(d['state'], 'lobby');
    expect((d['players'] as Map)['tg222']['ready'], isFalse);
    expect((d['players'] as Map)['tg222']['moves'], isEmpty);
    db.dispose();
  });

  test("4 kishidan ortiq kirmaydi; chiqib ketish; xo'jayin almashadi", () {
    final db = Store();
    final code = (call(db, 'tg111', 'stack.create') as Map)['code'] as String;
    for (final u in ['tg2', 'tg3', 'tg4']) {
      call(db, u, 'stack.join', {'code': code});
    }
    expect(() => call(db, 'tg5', 'stack.join', {'code': code}), throwsA(isA<GameError>()));
    call(db, 'tg111', 'stack.leave', {'code': code});
    final d = db.get('stack/$code')!;
    expect(d['host'], 'tg2');
    expect((d['players'] as Map).length, 3);
    for (final u in ['tg2', 'tg3', 'tg4']) {
      call(db, u, 'stack.leave', {'code': code});
    }
    expect(db.get('stack/$code'), isNull);
    db.dispose();
  });
}
