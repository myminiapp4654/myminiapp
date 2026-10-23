import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/ui/setup.dart';

Color? labelColor(WidgetTester t, String text) {
  final ctx = t.element(find.text(text));
  return DefaultTextStyle.of(ctx).style.color;
}

void main() {
  testWidgets("qiyinlik arqoni: surish va bosish darajani o'zgartiradi", (t) async {
    var level = 2;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (ctx, setState) => DifficultyRope(
                value: level,
                onChanged: (v) => setState(() => level = v),
              ),
            ),
          ),
        ),
      ),
    ));
    final rope = t.getRect(find.byKey(const ValueKey('rope')));

    await t.tapAt(Offset(rope.left + 10, rope.center.dy));
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 300)); // yozuv rangi silliq almashadi
    expect(level, 1);
    expect(labelColor(t, 'Oson'), isNot(Colors.white38));
    expect(labelColor(t, "O'rta"), Colors.white38);

    await t.dragFrom(Offset(rope.left + 32, rope.center.dy), Offset(rope.width, 0));
    await t.pump(const Duration(milliseconds: 700));
    await t.pump(const Duration(milliseconds: 300)); // yozuv rangi silliq almashadi
    expect(level, 3);
    expect(labelColor(t, 'Qiyin'), isNot(Colors.white38));
    expect(labelColor(t, 'Oson'), Colors.white38);
  });
}
