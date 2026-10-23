import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/screens/home_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(loadFonts);
  testWidgets('home', (t) async {
    await shoot(t, 'home', const HomeScreen());
    await t.pumpWidget(const SizedBox());
  });
}
