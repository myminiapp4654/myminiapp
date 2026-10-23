import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/battleship/battleship_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('battleship', (t) async {
    await shoot(t, 'bs_place', const BattleshipScreen(seed: 2), pumps: const [Duration(milliseconds: 400)],
        before: (t) async {
      await t.tap(find.text('Tasodifiy'));
      await t.pump(const Duration(milliseconds: 400));
    });
    await t.tap(find.byKey(const ValueKey('ready')));
    await t.pump(const Duration(milliseconds: 400));
    for (final k in [40, 41, 22, 58, 13, 67, 31, 49]) {
      await t.tap(find.byKey(ValueKey('target-$k')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 60));
      if (find.textContaining('Tegmadi').evaluate().isNotEmpty) break;
    }
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/bs_battle.png'));
    // Kompyuter navbati
    await t.pump(const Duration(milliseconds: 1000));
    await t.pump(const Duration(milliseconds: 1300));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/bs_ai.png'));
    await t.pumpWidget(const SizedBox());
  });
}
