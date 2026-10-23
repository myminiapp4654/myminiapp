import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/chess/chess_pieces.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('pieces', (t) async {
    await shoot(
      t,
      'pieces',
      Scaffold(
        backgroundColor: const Color(0xFFB58863),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final row in ['KQRBNP', 'kqrbnp'])
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final p in row.split('')) ChessPiece(piece: p, size: 66),
              ]),
          ]),
        ),
      ),
      size: const Size(420, 200),
    );
  });
}
