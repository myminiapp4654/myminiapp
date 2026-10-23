import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  String get _userName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> createRoom({int gridSize = 10}) async {
    final code = _generateRoomCode();
    await _db.collection('games').doc(code).set({
      'roomCode': code,
      'gridSize': gridSize,
      'board': List.filled(gridSize * gridSize, ''),
      'currentTurn': 'X',
      'player1': {'uid': _uid, 'name': _userName, 'symbol': 'X'},
      'player2': null,
      'status': 'waiting',
      'winner': null,
      'scoreX': 0,
      'scoreO': 0,
      'winningCells': <int>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> joinRoom(String code) async {
    final doc =
        await _db.collection('games').doc(code.toUpperCase()).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['status'] != 'waiting') return false;
    if (data['player1']['uid'] == _uid) return false;

    await _db.collection('games').doc(code.toUpperCase()).update({
      'player2': {'uid': _uid, 'name': _userName, 'symbol': 'O'},
      'status': 'playing',
    });
    return true;
  }

  Future<void> makeMove(String roomCode, int index) async {
    final ref = _db.collection('games').doc(roomCode);
    final doc = await ref.get();
    final data = doc.data()!;

    final board = List<String>.from(data['board']);
    final currentTurn = data['currentTurn'] as String;
    final player1Uid = data['player1']['uid'];
    final mySymbol = _uid == player1Uid ? 'X' : 'O';
    final gridSize = (data['gridSize'] as int?) ?? 10;

    if (currentTurn != mySymbol) return;
    if (board[index].isNotEmpty) return;

    board[index] = mySymbol;

    final newLines = _findNewLines(board, gridSize, index, mySymbol);
    final winningCells = List<int>.from(data['winningCells'] ?? []);
    int scoreX = (data['scoreX'] as int?) ?? 0;
    int scoreO = (data['scoreO'] as int?) ?? 0;

    for (final line in newLines) {
      winningCells.addAll(line);
      if (mySymbol == 'X') {
        scoreX++;
      } else {
        scoreO++;
      }
    }

    final boardFull = !board.contains('');
    String? winner;
    String status = 'playing';

    if (boardFull) {
      status = 'finished';
      if (scoreX > scoreO) {
        winner = 'X';
      } else if (scoreO > scoreX) {
        winner = 'O';
      } else {
        winner = 'draw';
      }
    }

    await ref.update({
      'board': board,
      'currentTurn': currentTurn == 'X' ? 'O' : 'X',
      'winningCells': winningCells,
      'scoreX': scoreX,
      'scoreO': scoreO,
      'winner': winner,
      'status': status,
    });
  }

  // Returns all NEW 5-in-a-row lines that include [index]
  List<List<int>> _findNewLines(
      List<String> board, int gridSize, int index, String symbol) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final List<List<int>> found = [];

    // [dr, dc] for 4 directions
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];

    for (final dir in dirs) {
      final dr = dir[0];
      final dc = dir[1];

      // Each 5-cell window that includes (row, col) along this direction
      for (int start = -4; start <= 0; start++) {
        final cells = <int>[];
        bool valid = true;

        for (int i = 0; i < 5; i++) {
          final r = row + (start + i) * dr;
          final c = col + (start + i) * dc;
          if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) {
            valid = false;
            break;
          }
          final idx = r * gridSize + c;
          if (board[idx] != symbol) {
            valid = false;
            break;
          }
          cells.add(idx);
        }

        if (valid && cells.length == 5) {
          found.add(List.from(cells));
        }
      }
    }
    return found;
  }

  Stream<DocumentSnapshot> gameStream(String roomCode) =>
      _db.collection('games').doc(roomCode).snapshots();

  Future<void> sendMessage(String roomCode, String text) async {
    await _db
        .collection('games')
        .doc(roomCode)
        .collection('messages')
        .add({
      'uid': _uid,
      'name': _userName,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> messagesStream(String roomCode) => _db
      .collection('games')
      .doc(roomCode)
      .collection('messages')
      .orderBy('sentAt', descending: false)
      .snapshots();

  Future<void> deleteRoom(String roomCode) async {
    await _db.collection('games').doc(roomCode).delete();
  }

  String get myUid => _uid;
  String get myName => _userName;
}
