import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/xo/xo_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('xo', (t) async {
    await shoot(t, 'xo_play', const XoScreen(size: 3, level: 1, seed: 4), pumps: const [Duration(milliseconds: 400)],
        before: (t) async {
      for (final i in [4, 0]) {
        await t.tap(find.byKey(ValueKey('cell-$i')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 900));
      }
    });
    await shoot(t, 'xo10_play', const XoScreen(key: ValueKey(10), size: 10, level: 3, seed: 4), pumps: const [Duration(milliseconds: 400)],
        before: (t) async {
      for (final i in [44, 45, 54, 55]) {
        await t.tap(find.byKey(ValueKey('cell-$i')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 900));
      }
    });
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
