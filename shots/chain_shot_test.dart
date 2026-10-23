import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chain/chain_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('chain', (t) async {
    await shoot(
      t,
      'chain',
      const ChainScreen(players: 3, level: 2, seed: 5),
      pumps: const [Duration(milliseconds: 150)],
      before: (t) async {
        for (final i in [0, 0, 7, 13, 6, 12, 1, 2, 3, 8]) {
          await t.tap(find.byKey(ValueKey('cell-$i')), warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 2500));
        }
        await t.tap(find.byKey(const ValueKey('cell-8')), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 250));
      },
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
