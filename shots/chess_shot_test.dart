import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chess/chess_game.dart';
import 'package:oyinim/games/chess/chess_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('chess', (t) async {
    final g = ChessGame();
    for (final m in ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'f3g5', 'd7d5', 'e4d5', 'f6d5', 'g5f7']) {
      g.playUci(m);
    }
    await shoot(t, 'chess', ChessScreen(vsAi: true, level: 2, initialGame: g),
        pumps: const [Duration(milliseconds: 100)]);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
