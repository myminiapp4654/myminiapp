import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/stack/stack_game.dart';
import 'package:oyinim/games/stack/stack_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Suzayotgan blokni pastdagisidan [delta] siljigan joyga qo'yadi.
StackResult placeAt(StackGame g, double delta) {
  g.offset = delta;
  g.update(0); // joyini yangilash
  return g.place();
}

void main() {
  test("aniq qo'yilsa kesilmaydi, qavat qo'shiladi", () {
    final g = StackGame();
    expect(placeAt(g, 0.1), StackResult.perfect);
    expect(g.score, 1);
    expect(g.top.w, StackGame.base);
    expect(g.top.x, g.tower.first.x);
    expect(g.pieces, isEmpty);
  });

  test("qiyshiq qo'yilsa chiqib turgan qismi kesiladi", () {
    final g = StackGame();
    expect(g.alongX, isTrue);
    expect(placeAt(g, 3), StackResult.placed);
    expect(g.top.w, closeTo(7, 1e-9));
    expect(g.top.x, closeTo(-2, 1e-9)); // -5 + 3
    expect(g.pieces.single.box.w, closeTo(3, 1e-9));
    expect(g.pieces.single.box.x, closeTo(5, 1e-9));
    // Keyingi qavat Z o'qi bo'ylab, yangi kenglik bilan
    expect(g.alongX, isFalse);
    expect(g.moving.w, closeTo(7, 1e-9));
    expect(placeAt(g, -2), StackResult.placed);
    expect(g.top.d, closeTo(8, 1e-9));
    expect(g.top.z, closeTo(-5, 1e-9));
  });

  test("umuman tegmasa — o'yin tugaydi", () {
    final g = StackGame();
    expect(placeAt(g, 10.5), StackResult.missed);
    expect(g.over, isTrue);
    expect(g.score, 0);
    expect(g.place(), StackResult.missed);
  });

  test("ketma-ket aniq qo'yishlar blokni kattalashtiradi (asosdan oshmaydi)", () {
    final g = StackGame();
    placeAt(g, 2); // 8 kenglik
    expect(g.top.w, closeTo(8, 1e-9));
    var w = g.top.w, d = g.top.d;
    for (var k = 0; k < 6; k++) {
      expect(placeAt(g, 0), StackResult.perfect);
    }
    expect(g.combo, 6);
    expect(g.top.w, greaterThan(w));
    expect(g.top.w, lessThanOrEqualTo(StackGame.base));
    expect(g.top.d, lessThanOrEqualTo(StackGame.base));
    w = g.top.w;
    d = g.top.d;
    placeAt(g, 1); // seriya uziladi
    expect(g.combo, 0);
    expect(d, StackGame.base);
  });

  test("blok chegaralar orasida borib-keladi, tezlik qavat sari oshadi", () {
    final g = StackGame();
    final v0 = g.speed;
    for (var k = 0; k < 600; k++) {
      g.update(1 / 60);
      expect(g.offset.abs(), lessThanOrEqualTo(StackGame.range + 1e-9));
    }
    for (var k = 0; k < 10; k++) {
      placeAt(g, 0);
    }
    expect(g.speed, greaterThan(v0));
  });

  testWidgets("ekran: bosish — boshlash, bosish — qo'yish, tugash oynasi", (t) async {
    SharedPreferences.setMockInitialValues({'stack_best': 3});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: StackScreen()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Bosing — boshlang'), findsOneWidget);
    expect(find.text('Rekordingiz: 3'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('stack')));
    await t.pump(const Duration(milliseconds: 50));
    // Tezda bosib turamiz — kech yoki erta bosish oxiri o'yinni tugatadi
    for (var k = 0; k < 60 && find.text("Yana o'ynash").evaluate().isEmpty; k++) {
      await t.tap(find.byKey(const ValueKey('stack')));
      for (var f = 0; f < 20; f++) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }
    expect(find.text("Yana o'ynash"), findsOneWidget);
    await t.tap(find.text("Yana o'ynash"));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('0'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
