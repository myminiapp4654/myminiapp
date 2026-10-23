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
      expect(find.byKey(const ValueKey('game-Ilon va narvon')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
    t.view.reset();
  });

  testWidgets("oddiy foydalanuvchiga faqat Stack, adminga hammasi; murojaat tugmasi", (t) async {
    await t.pumpWidget(const MaterialApp(home: HomeScreen(allGames: false)));
    await t.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('game-Stack')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-Shaxmat')), findsNothing);
    expect(find.text('Murojaat: @Ulugbeck_dev'), findsOneWidget);
    await t.pumpWidget(const MaterialApp(home: HomeScreen(allGames: true)));
    await t.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('game-Shaxmat')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
