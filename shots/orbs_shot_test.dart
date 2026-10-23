// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/orbs/orbs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('orbs', (t) async {
    SharedPreferences.setMockInitialValues({'orbs_progress_v1': '{"1":3,"2":2,"3":1}'});
    await shoot(t, 'orbs', const OrbsScreen(), pumps: const [Duration(milliseconds: 120)],
        before: (t) async {
      await t.pump(const Duration(milliseconds: 200));
      final arena = t.getRect(find.byKey(const ValueKey('arena')));
      await t.tapAt(Offset(arena.center.dx, arena.bottom - arena.width / 9 * 1.5));
      for (var k = 0; k < 6; k++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    });
    await t.pumpWidget(const SizedBox());
  });
}
