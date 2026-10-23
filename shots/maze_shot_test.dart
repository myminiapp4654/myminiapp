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
    // Biroz chizamiz: kirishdan pastga
    final rect = t.getRect(find.byKey(const ValueKey('maze')));
    final cell = rect.width / 29;
    final g = await t.startGesture(rect.topLeft + Offset(cell * 1.5, cell * 0.5));
    for (var k = 0; k < 40; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    for (var k = 0; k < 60; k++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/maze_play.png'));
    await t.pumpWidget(const SizedBox());
  });
}
