import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/knife/knife_game.dart';
import 'package:oyinim/games/knife/knife_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void run(KnifeGame g, double seconds) {
  for (var k = 0; k < (seconds * 60).round(); k++) {
    g.update(1 / 60);
  }
}

double gap(double a, double b) {
  final d = (a - b).abs() % (2 * pi);
  return d > pi ? 2 * pi - d : d;
}

void main() {
  test("pichoq uchib, pastki nuqtaga sanchiladi; uchayotganda qayta otilmaydi", () {
    final g = KnifeGame(seed: 1)..knives.clear()..apples.clear();
    final total = g.left;
    expect(g.throwKnife(), isTrue);
    expect(g.throwKnife(), isFalse);
    run(g, 0.2);
    expect(g.knives.length, 1);
    expect(g.score, 1);
    expect(g.left, total - 1);
  });

  test("sanchilgan pichoqqa tegsa — o'yin tugaydi", () {
    final g = KnifeGame(seed: 1)..apples.clear();
    g.knives
      ..clear()
      ..add(StuckKnife(g.hitAngle)); // aynan tegadigan joyda
    g.pattern = RotationPattern(0, 0, 1, 1); // aylanmasin
    g.throwKnife();
    run(g, 0.2);
    expect(g.over, isTrue);
    expect(g.events.last.type, KnifeEventType.fail);
  });

  test("olmaga tegsa — bonus; hamma pichoq sanchilsa — keyingi bosqich", () {
    final g = KnifeGame(seed: 2)..knives.clear();
    g.pattern = RotationPattern(0, 0, 1, 1);
    g.apples
      ..clear()
      ..add(g.hitAngle);
    g.throwKnife();
    run(g, 0.2);
    expect(g.applesHit, 1);
    g.pattern = RotationPattern(2.5, 0, 1, 1);
    while (g.left > 0) {
      g.throwKnife();
      run(g, 0.45);
    }
    expect(g.clearedAt, isNotNull);
    run(g, 1.3);
    expect(g.stage, 2);
    expect(g.left, g.stageKnives);
  });

  test("har 5-bosqich — boss, unda pichoq va to'siq ko'proq", () {
    final g = KnifeGame(seed: 3);
    g.stage = 5;
    expect(g.isBoss, isTrue);
    g.stage = 4;
    expect(g.isBoss, isFalse);
  });

  test("ehtiyotkor o'yinchi 15 bosqichdan o'ta oladi (o'yin adolatli)", () {
    for (var seed = 0; seed < 10; seed++) {
      final g = KnifeGame(seed: seed);
      var guard = 0;
      while (!g.over && g.stage <= 15 && guard++ < 60 * 1200) {
        g.update(1 / 60);
        if (g.flyingSince != null || g.clearedAt != null) continue;
        // Uchish vaqtida nishon qayerga borishini taxmin qilib, bo'sh joyga otadi
        var future = 0.0;
        for (var i = 0; i < 12; i++) {
          future += g.pattern.speedAt(g.stageTime + (i + 0.5) * KnifeGame.flight / 12) * KnifeGame.flight / 12;
        }
        final at = g.hitAngle - future;
        if (g.knives.every((k) => gap(k.angle, at) > KnifeGame.knifeGap * 1.25)) g.throwKnife();
      }
      expect(g.over, isFalse, reason: 'seed $seed: ${g.stage}-bosqichda yiqildi');
      expect(g.stage, greaterThan(15));
    }
  });

  testWidgets("ekran: bosish — pichoq otiladi, tugaganda natija oynasi", (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: KnifeScreen(seed: 4)));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('1-bosqich'), findsOneWidget);
    final area = find.byKey(const ValueKey('knife'));
    // Tez-tez otamiz — oxiri pichoqqa tegadi
    for (var k = 0; k < 200 && find.text("Yana o'ynash").evaluate().isEmpty; k++) {
      await t.tap(area);
      await t.pump(const Duration(milliseconds: 130));
    }
    expect(find.text("Yana o'ynash"), findsOneWidget);
    await t.tap(find.text("Yana o'ynash"));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('1-bosqich'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
