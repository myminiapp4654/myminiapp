import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/xo/xo_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('xo', (t) async {
    await shoot(t, 'xo_play', const XoScreen(size: 3), pumps: const [Duration(milliseconds: 400)],
        before: (t) async {
      for (final i in [4, 0, 8]) {
        await t.tap(find.byKey(ValueKey('cell-$i')));
        await t.pump(const Duration(milliseconds: 300));
      }
    });
    for (final i in [2, 6, 1, 7]) {
      await t.tap(find.byKey(ValueKey('cell-$i')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
    }
    await t.pump(const Duration(milliseconds: 600));
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/xo_win.png'));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
