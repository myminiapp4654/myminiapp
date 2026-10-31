import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/knife/knife_screen.dart';
import 'package:oyinim/ui/game_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('knife', (t) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await shoot(t, 'knife', const KnifeScreen(seed: 7), pumps: const [Duration(milliseconds: 16)],
        before: (t) async {
      final area = find.byKey(const ValueKey('knife'));
      for (var k = 0; k < 3; k++) {
        await t.tap(area);
        for (var f = 0; f < 45; f++) {
          await t.pump(const Duration(milliseconds: 16));
        }
      }
    });
    await shoot(
      t,
      'knife_art',
      Container(
        color: const Color(0xFF2A1B4D),
        alignment: Alignment.topCenter,
        child: SizedBox(width: 300, height: 300, child: CustomPaint(painter: GameArtPainter(GameArt.knife, 0.2))),
      ),
      pumps: const [Duration(milliseconds: 16)],
    );
    await t.pumpWidget(const SizedBox());
  });
}
