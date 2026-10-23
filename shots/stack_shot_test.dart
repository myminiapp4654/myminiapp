import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/stack/stack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('stack', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'stack_best': 12});
    await shoot(t, 'stack_ready', const StackScreen(), pumps: const [Duration(milliseconds: 300)]);
    final area = find.byKey(const ValueKey('stack'));
    await t.tap(area);
    // Har ~1.4 soniyada bosamiz: blok markazga yaqinlashganda
    for (var k = 0; k < 9; k++) {
      for (var f = 0; f < 88; f++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.tap(area);
    }
    for (var f = 0; f < 20; f++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/stack_play.png'));
    await t.pumpWidget(const SizedBox());
  });
}
