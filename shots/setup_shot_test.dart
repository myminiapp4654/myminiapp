import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/screens/home_screen.dart';

import 'shot.dart';

Future<void> openGame(WidgetTester t, String title) async {
  final tile = find.byKey(ValueKey('game-$title'));
  await t.ensureVisible(tile);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(tile);
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadFonts);

  testWidgets('chess setup', (t) async {
    await shoot(t, 'setup_chess_easy', const HomeScreen(), pumps: const [Duration(milliseconds: 100), Duration(milliseconds: 400)],
        before: (t) async {
      await t.pump(const Duration(milliseconds: 1200));
      await openGame(t, 'Shaxmat');
      // Emoji rasmlari yuklanib ulgursin
      await t.runAsync(() async {
        for (final e in t.widgetList<Image>(find.byType(Image))) {
          await precacheImage(e.image, t.element(find.byType(Image).first));
        }
      });
      await t.pump(const Duration(milliseconds: 100));
      final rope = t.getRect(find.byKey(const ValueKey('rope')));
      await t.tapAt(Offset(rope.left + 20, rope.center.dy));
      await t.pump(const Duration(milliseconds: 600));
    });
    final rope = t.getRect(find.byKey(const ValueKey('rope')));
    await t.dragFrom(Offset(rope.left + 32, rope.center.dy), Offset(rope.width - 20, 0));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/setup_chess_hard.png'));
    await t.tapAt(rope.center);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/setup_chess_mid.png'));
  });

  testWidgets('ludo setup', (t) async {
    await shoot(t, 'setup_ludo', const HomeScreen(), pumps: const [Duration(milliseconds: 100), Duration(milliseconds: 400)],
        before: (t) async {
      await t.pump(const Duration(milliseconds: 1200));
      await openGame(t, 'Ludo');
      await t.tap(find.byKey(const ValueKey('count-4')));
      await t.pump(const Duration(milliseconds: 800));
    });
  });

  testWidgets('chain setup', (t) async {
    await shoot(t, 'setup_chain', const HomeScreen(), pumps: const [Duration(milliseconds: 100), Duration(milliseconds: 400)],
        before: (t) async {
      await t.pump(const Duration(milliseconds: 1200));
      await openGame(t, 'Chain Reaction');
      await t.tap(find.byKey(const ValueKey('count-5')));
      await t.pump(const Duration(milliseconds: 800));
    });
  });
}
