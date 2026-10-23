import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/battleship/battleship_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('battleship', (t) async {
    await shoot(t, 'bs_cover', const BattleshipScreen());
    // Joylashtirish
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Tasodifiy'));
    await t.pump(const Duration(milliseconds: 400));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/bs_place.png'));
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Tasodifiy'));
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pump(const Duration(milliseconds: 400));
    // Bir nechta otish
    final rnd = Random(2);
    for (var k = 0; k < 14; k++) {
      final f = find.byKey(ValueKey('target-${rnd.nextInt(81)}'));
      await t.tap(f, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
      if (find.byKey(const ValueKey('pass')).evaluate().isNotEmpty) break;
    }
    await t.pump(const Duration(milliseconds: 200));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/bs_battle.png'));
  });
}
