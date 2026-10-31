import 'dart:io';

import 'package:oyinim_server/oyinim_server.dart';
import 'package:test/test.dart';

void main() {
  test("botga kirganlar yoziladi, hisobotda ko'rinadi, faylda saqlanadi", () {
    final dir = Directory.systemTemp.createTempSync('botusers');
    final db = Store(dataDir: dir.path);
    final bot = TelegramBot(token: 't', publicUrl: 'https://x', db: db, adminIds: {'1'});
    bot.recordUser({'id': 10, 'first_name': 'Ali', 'last_name': 'Valiyev', 'username': 'ali'}, start: true);
    bot.recordUser({'id': 11, 'first_name': 'Vali <b>'}, start: true);
    bot.recordUser({'id': 10, 'first_name': 'Ali'}); // qayta yozdi

    final u = db.get('botusers/10')!;
    expect(u['starts'], 1);
    expect(u['name'], 'Ali');
    final report = bot.usersReport();
    expect(report, contains('Botga kirganlar: 2'));
    expect(report, contains('<code>10</code>'));
    expect(report, contains('Vali &lt;b&gt;')); // HTML xavfsiz
    db.dispose();

    final again = Store(dataDir: dir.path);
    expect(again.pathsIn('botusers').length, 2);
    again.dispose();
    dir.deleteSync(recursive: true);
  });

  test("admin.users: faqat admin, ikkala ro'yxat", () {
    final db = Store();
    final bot = TelegramBot(token: 't', publicUrl: 'https://x', db: db);
    bot.recordUser({'id': 10, 'first_name': 'Ali'}, start: true);
    db.set('users/tg10', {'uid': 'tg10', 'name': 'Ali', 'first': 1, 'last': 2});
    final h = adminHandlers({'1'})['admin.users']!;
    expect(() => h(Ctx(db, 'tg10', 'Ali'), {}), throwsA(isA<GameError>()));
    final r = h(Ctx(db, 'tg1', 'Admin'), {}) as Map;
    expect((r['bot'] as List).single['name'], 'Ali');
    expect((r['app'] as List).single['uid'], 'tg10');
    db.dispose();
  });
}
