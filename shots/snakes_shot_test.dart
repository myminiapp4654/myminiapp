import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/snakes/snakes_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('snakes', (t) async {
    await shoot(t, 'snakes', const SnakesScreen(players: 3, seed: 7), pumps: const [Duration(milliseconds: 300)],
        before: (t) async {
      for (var k = 0; k < 4; k++) {
        await t.tap(find.byKey(const ValueKey('dice')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 100));
        for (var i = 0; i < 70 && find.text('Zarni bosing!').evaluate().isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }
    });
    await shoot(t, 'snakes_b', const SnakesScreen(key: ValueKey(2), players: 2, seed: 21),
        pumps: const [Duration(milliseconds: 300)]);
    await t.pumpWidget(const SizedBox());
  });
}
