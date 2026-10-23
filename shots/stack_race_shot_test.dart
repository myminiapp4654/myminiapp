import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/stack/stack_race_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('stack race', (t) async {
    await shoot(t, 'stack_race', const StackRaceScreen(bots: 3, level: 2, seed: 3),
        pumps: const [Duration(milliseconds: 16)], before: (t) async {
      final area = find.byKey(const ValueKey('stack-race'));
      // Sanoq
      for (var f = 0; f < 190; f++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      for (var k = 0; k < 6; k++) {
        for (var f = 0; f < 88; f++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        await t.tap(area);
      }
      for (var f = 0; f < 30; f++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    });
    // Yiqilamiz va kuzatamiz
    final area = find.byKey(const ValueKey('stack-race'));
    for (var k = 0; k < 30 && find.text("Yana o'ynash").evaluate().isEmpty; k++) {
      await t.tap(area);
      for (var f = 0; f < 3; f++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }
    for (var k = 0; k < 3000 && find.text("Yana o'ynash").evaluate().isEmpty; k++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(milliseconds: 300));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/stack_race_end.png'));
    await t.pumpWidget(const SizedBox());
  });
}
