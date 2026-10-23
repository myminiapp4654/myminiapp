import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/screens/home_screen.dart';

void main() {
  testWidgets("bosh ekran: 8 ta o'yin kartochkasi, kichik ekranda ham sig'adi", (t) async {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(const MaterialApp(home: HomeScreen()));
      await t.pump(const Duration(milliseconds: 1200));
      expect(t.takeException(), isNull);
      expect(find.byKey(const ValueKey('game-Ludo')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
    t.view.reset();
  });
}
