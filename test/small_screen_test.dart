import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/battleship/battleship_screen.dart';
import 'package:oyinim/games/chain/chain_screen.dart';
import 'package:oyinim/games/checkers/checkers_screen.dart';
import 'package:oyinim/games/chess/chess_screen.dart';
import 'package:oyinim/games/maze/maze_screen.dart';
import 'package:oyinim/games/snake/snake_screen.dart';
import 'package:oyinim/games/snakes/snakes_screen.dart';
import 'package:oyinim/games/stack/stack_race_screen.dart';
import 'package:oyinim/games/stack/stack_screen.dart';
import 'package:oyinim/games/walls/walls_screen.dart';
import 'package:oyinim/games/xo/xo_screen.dart';
import 'package:oyinim/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'snakes4': const SnakesScreen(players: 4, seed: 1),
    'maze3': const MazeScreen(level: 3, seed: 1),
    'snake': const SnakeScreen(level: 2, seed: 1),
    'chess': const ChessScreen(),
    'battleship': const BattleshipScreen(),
    'checkers': const CheckersScreen(),
    'xo3': const XoScreen(size: 3),
    'xo10': const XoScreen(size: 10),
    'chain8': const ChainScreen(players: 8, rows: 12, cols: 8),
    'orbs': const StackScreen(),
    'stackRace': const StackRaceScreen(bots: 3, seed: 1),
    'walls': const WallsScreen(),
  };

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    for (final e in screens.entries) {
      testWidgets("${e.key}: ${size.width.toInt()}×${size.height.toInt()} da sig'adi", (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(home: e.value));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
      });
    }
  }
}
