import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chain/chain_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('chain', (t) async {
    await shoot(t, 'chain', const ChainScreen(players: 3), pumps: const [Duration(milliseconds: 150)],
        before: (t) async {
      for (final i in [0, 20, 40, 7, 21, 41, 7, 22, 46, 13, 27, 47, 7]) {
        await t.tap(find.byKey(ValueKey('cell-$i')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 900));
      }
      await t.tap(find.byKey(const ValueKey('cell-8')), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 250));
    });
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
