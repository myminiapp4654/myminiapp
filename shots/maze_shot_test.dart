import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/maze/maze_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('maze', (t) async {
    await shoot(t, 'maze_start', const MazeScreen(level: 2, seed: 4), pumps: const [Duration(milliseconds: 300)]);
    await t.tap(find.byKey(const ValueKey('start')));
    for (var k = 0; k < 30; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // Bir necha marta suramiz
    final c = t.getCenter(find.byKey(const ValueKey('maze')));
    for (final d in const [Offset(0, 60), Offset(60, 0), Offset(0, 60), Offset(-60, 0), Offset(0, 60)]) {
      await t.dragFrom(c, d);
      for (var k = 0; k < 15; k++) {
        await t.pump(const Duration(milliseconds: 60));
      }
    }
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/maze_play.png'));
    await t.pumpWidget(const SizedBox());
  });
}
