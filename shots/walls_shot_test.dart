import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/walls/walls_game.dart';
import 'package:oyinim/games/walls/walls_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('walls', (t) async {
    final g = WallsGame(random: Random(5))
      ..wall = 6
      ..money = 1530
      ..tool = 1
      ..workerLvl = 2
      ..scanner = true
      ..dynamite = 2;
    final rnd = Random(9);
    g.bricks = [
      for (var i = 0; i < 48; i++)
        Brick(BrickType.values[[0, 0, 0, 1, 1, 2, 3, 4, 5][rnd.nextInt(9)]], 10)
          ..hp = [10.0, 10.0, 6.0, 3.0, 0.0][rnd.nextInt(5)],
    ];
    SharedPreferences.setMockInitialValues({'walls_save_v1': jsonEncode(g.toJson())});
    await shoot(t, 'walls', const WallsScreen(), pumps: const [Duration(milliseconds: 300)]);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 200));
  });
}
