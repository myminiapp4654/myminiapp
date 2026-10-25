import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/checkers/checkers_screen.dart';
import 'dart:async';

import 'package:oyinim/games/chess/chess_screen.dart';
import 'package:oyinim/games/snake/snake_screen.dart';
import 'package:oyinim/net/online_match.dart';

/// Server o'rniga: yuborilgan yurishlar ro'yxatga tushadi.
class FakeMatch {
  final moves = ValueNotifier<List<String>>(const []);
  final left = ValueNotifier<String?>(null);
  final sent = <String>[];
  var ended = false;

  OnlineMatch build({required bool iAmFirst}) => OnlineMatch(
        code: 'ABC123',
        myUid: 'me',
        players: const [('me', 'Men'), ('foe', 'Ali')],
        first: iAmFirst ? 'me' : 'foe',
        seed: 1,
        countdown: 0,
        moves: moves,
        left: left,
        send: (m) {
          sent.add(m);
          moves.value = [...moves.value, m]; // server aks-sadosi
        },
        end: () => ended = true,
        again: () {},
      );
}

int sq(int r, int c) => r * 8 + c;

void main() {
  setUp(() {});

  testWidgets("shaxmat onlayn: oq yuradi, yurish yuboriladi, raqib javobi taxtaga tushadi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final f = FakeMatch();
    await t.pumpWidget(MaterialApp(home: ChessScreen(online: f.build(iAmFirst: true))));
    await t.pump();
    expect(find.text('Sizning navbatingiz'), findsOneWidget);
    expect(find.text('Men (siz)'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('sq-e2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sq-e4')));
    await t.pump();
    expect(f.sent, ['e2e4']);
    expect(find.text("Raqib o'ylayapti..."), findsOneWidget);

    // Raqib navbatida bosish hech narsa qilmaydi
    await t.tap(find.byKey(const ValueKey('sq-d2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sq-d4')));
    await t.pump();
    expect(f.sent, ['e2e4']);

    f.moves.value = ['e2e4', 'e7e5'];
    await t.pump();
    expect(find.text('Sizning navbatingiz'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("shaxmat onlayn: qora o'yinchi oq yurishini kutadi; raqib chiqsa — yutdingiz", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final f = FakeMatch();
    await t.pumpWidget(MaterialApp(home: ChessScreen(online: f.build(iAmFirst: false))));
    await t.pump();
    expect(find.text("Raqib o'ylayapti..."), findsOneWidget);
    f.moves.value = ['d2d4'];
    await t.pump();
    expect(find.text('Sizning navbatingiz'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sq-d7')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('sq-d5')));
    await t.pump();
    expect(f.sent, ['d7d5']);
    f.left.value = 'foe';
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Raqib chiqib ketdi'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("shashka onlayn: qora o'yinchi — raqib yurishi qo'llanadi, o'z yurishi yuboriladi", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final f = FakeMatch();
    await t.pumpWidget(MaterialApp(home: CheckersScreen(online: f.build(iAmFirst: false))));
    await t.pump();
    expect(find.text("Ali o'ylayapti…"), findsOneWidget);
    f.moves.value = ['${sq(5, 2)}-${sq(4, 3)}'];
    await t.pump(const Duration(milliseconds: 800));
    expect(find.textContaining('Sizning navbatingiz'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('sq-${sq(2, 5)}')));
    await t.pump();
    await t.tap(find.byKey(ValueKey('sq-${sq(3, 4)}')));
    await t.pump(const Duration(milliseconds: 100));
    expect(f.sent, ['${sq(2, 5)}-${sq(3, 4)}']);
    expect(find.text("Ali o'ylayapti…"), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets("neon snake onlayn: holat yuboriladi, raqib ilonchasi paydo bo'ladi, raund vaqti", (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final sent = <Map<String, dynamic>>[];
    final foe = StreamController<Map<String, dynamic>?>();
    final match = OnlineMatch(
      code: 'ABC123',
      myUid: 'me',
      players: const [('me', 'Men'), ('foe', 'Ali')],
      first: 'me',
      seed: 5,
      countdown: 0,
      moves: ValueNotifier(const []),
      left: ValueNotifier(null),
      send: (_) {},
      end: () {},
      again: () {},
      sendState: sent.add,
      watchState: (uid) => foe.stream,
    );
    await t.pumpWidget(MaterialApp(home: SnakeScreen(online: match)));
    for (var k = 0; k < 6; k++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(sent, isNotEmpty);
    expect(sent.last['v'], isTrue);
    expect(find.byKey(const ValueKey('round-time')), findsOneWidget);
    foe.add({'x': 100.0, 'y': 0.0, 'a': 0.0, 'l': 20, 'v': true, 'n': 0, 'b': 20, 'e': <String>[]});
    await t.pump(const Duration(milliseconds: 60));
    expect(find.text('Ali'), findsWidgets); // reytingda
    await t.pumpWidget(const SizedBox());
    unawaited(foe.close());
  });
}
