import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyinim/games/xo_view.dart';
import 'package:oyinim/net/server_client.dart';

Map<String, dynamic> room({
  required List<String> board,
  String turn = 'X',
  String status = 'playing',
  String? winner,
  List<int> line = const [],
  List<String> rematch = const [],
  bool opponentOnline = true,
}) =>
    {
      'code': 'ABC123',
      'host': 'tg1',
      'players': {
        'tg1': {'name': 'Ali', 'online': true},
        'tg2': {'name': 'Vali', 'online': opponentOnline},
      },
      'game': {
        'type': 'xo',
        'size': 3,
        'winLen': 3,
        'board': board,
        'x': 'tg1',
        'o': 'tg2',
        'turn': turn,
        'status': status,
        'winner': winner,
        'line': line,
        'lastMove': null,
        'score': {'tg1': 2, 'tg2': 1},
        'draws': 0,
        'round': 4,
        'rematch': rematch,
      },
    };

Future<void> pump(WidgetTester t, Map<String, dynamic> r) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: XoView(roomCode: 'ABC123', room: r)),
      ),
    );

void main() {
  setUp(() => ServerClient.instance.user.value = const AppUser('tg1', 'Ali'));

  test("Doc: bo'sh hujjat mavjud emas", () {
    expect(const Doc(null).exists, isFalse);
    expect(const Doc({'a': 1}).data(), {'a': 1});
  });

  testWidgets('X-O: navbat, hisob va belgilar', (t) async {
    await pump(t, room(board: ['X', '', '', '', 'O', '', '', '', '']));
    expect(find.text('Sizning navbatingiz (X)'), findsOneWidget);
    expect(find.text('2 : 1'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
    expect(find.text("O'yinni tugatish"), findsOneWidget);
  });

  testWidgets('X-O: raqib navbati va aloqada emas', (t) async {
    await pump(
        t,
        room(
            board: List.filled(9, ''),
            turn: 'O',
            opponentOnline: false));
    expect(find.text('Vali navbati'), findsOneWidget);
    expect(find.text('Vali aloqada emas'), findsOneWidget);
  });

  testWidgets("X-O: g'alaba va qayta o'yin taklifi", (t) async {
    await pump(
        t,
        room(
          board: ['X', 'X', 'X', 'O', 'O', '', '', '', ''],
          status: 'finished',
          winner: 'X',
          line: [0, 1, 2],
          rematch: ['tg2'],
        ));
    expect(find.text('Siz yutdingiz!'), findsOneWidget);
    expect(find.text("Vali yana o'ynamoqchi"), findsOneWidget);
    expect(find.text("Yana o'ynash"), findsOneWidget);
    expect(find.text('Xonaga qaytish'), findsOneWidget);
  });

  testWidgets('X-O: durang', (t) async {
    await pump(
        t,
        room(
          board: ['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X'],
          status: 'finished',
          winner: 'draw',
        ));
    expect(find.text('Durang'), findsOneWidget);
  });
}
