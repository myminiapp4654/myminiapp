import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/checkers/checkers_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('checkers', (t) async {
    await shoot(t, 'checkers', const CheckersScreen(), pumps: const [Duration(milliseconds: 100)],
        before: (t) async {
      for (final i in [42, 33, 21, 30]) {
        await t.tap(find.byKey(ValueKey('sq-$i')));
        await t.pump(const Duration(milliseconds: 300));
      }
      await t.tap(find.byKey(const ValueKey('sq-44')));
      await t.pump(const Duration(milliseconds: 300));
    });
    await t.pumpWidget(const SizedBox());
  });
}
