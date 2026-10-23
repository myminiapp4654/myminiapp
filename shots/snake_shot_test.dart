import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/snake/snake_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('snake', (t) async {
    await shoot(t, 'snake', const SnakeScreen(level: 3, seed: 2), pumps: const [Duration(milliseconds: 16)],
        before: (t) async {
      final c = t.getCenter(find.byKey(const ValueKey('arena')));
      final g = await t.startGesture(c);
      await g.moveBy(const Offset(30, -10));
      for (var k = 0; k < 150; k++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    });
    await t.pumpWidget(const SizedBox());
  });
}
