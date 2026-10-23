// Ekran rasmlari (dizaynni ko'rib chiqish uchun):
//   flutter test shots/ --update-goldens
// Rasmlar shots/out/ papkasiga tushadi.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/ui/theme.dart';

const _fonts = '/src/flutter/bin/cache/artifacts/material_fonts';

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'C:$_fonts/roboto-regular.ttf',
    'C:$_fonts/roboto-medium.ttf',
    'C:$_fonts/roboto-bold.ttf',
    'C:$_fonts/roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['C:$_fonts/materialicons-regular.otf']);
  await load('SegoeSym', ['C:/Windows/Fonts/seguisym.ttf']);
}

Future<void> shoot(WidgetTester t, String name, Widget screen,
    {Size size = const Size(412, 892), List<Duration> pumps = const [Duration(milliseconds: 1500)],
    Future<void> Function(WidgetTester t)? before}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(RepaintBoundary(
    key: const ValueKey('shot'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(fontFamily: 'Roboto', fallback: const ['SegoeSym']),
      home: screen,
    ),
  ));
  if (before != null) await before(t);
  for (final d in pumps) {
    await t.pump(d);
  }
  await expectLater(find.byKey(const ValueKey('shot')), matchesGoldenFile('out/$name.png'));
}
