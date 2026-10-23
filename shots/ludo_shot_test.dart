import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/ludo/ludo_game.dart';
import 'package:oyinim/games/ludo/ludo_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('ludo', (t) async {
    final g = LudoGame(colors: [0, 1, 2, 3], ai: {1, 2, 3});
    g.tokens[0] = [5, 20, -1, 53];
    g.tokens[1] = [3, -1, -1, -1];
    g.tokens[2] = [10, 30, -1, kLudoHome];
    g.tokens[3] = [40, -1, -1, -1];
    await shoot(t, 'ludo', LudoScreen(players: 4, ai: const {1, 2, 3}, initialGame: g));
    await t.pumpWidget(const SizedBox());
  });
}
