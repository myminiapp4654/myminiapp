import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/checkers/checkers_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('checkers', (t) async {
    await shoot(t, 'checkers', const CheckersScreen(level: 2, seed: 3), pumps: const [Duration(milliseconds: 100)],
        before: (t) async {
      for (final m in [(42, 33), (46, 37)]) {
        await t.tap(find.byKey(ValueKey('sq-${m.$1}')));
        await t.pump(const Duration(milliseconds: 100));
        await t.tap(find.byKey(ValueKey('sq-${m.$2}')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 1500));
      }
      await t.tap(find.byKey(const ValueKey('sq-51')));
    });
    await t.pumpWidget(const SizedBox());
  });
}
