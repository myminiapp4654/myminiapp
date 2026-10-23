import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CheckersService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  // Board: 64 cells. '' empty, 'w' white, 'b' black, 'W' white king, 'B' black king
  // Dark squares only: (row+col)%2 == 1
  // White (player1): rows 5-7, moves UP (row--)
  // Black (player2): rows 0-2, moves DOWN (row++)
  List<String> _initialBoard() {
    final board = List.filled(64, '');
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) board[row * 8 + col] = 'b';
      }
    }
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) board[row * 8 + col] = 'w';
      }
    }
    return board;
  }

  Future<String> createRoom() async {
    final code = _genCode();
    await _db.collection('checkers').doc(code).set({
      'roomCode': code,
      'board': _initialBoard(),
      'currentTurn': 'w',
      'player1': {'uid': myUid, 'name': myName, 'color': 'w'},
      'player2': null,
      'status': 'waiting',
      'winner': null,
      'chainJump': -1,
      'lastMove': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> joinRoom(String code) async {
    final doc =
        await _db.collection('checkers').doc(code.toUpperCase()).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['status'] != 'waiting') return false;
    if (data['player1']['uid'] == myUid) return false;
    await _db.collection('checkers').doc(code.toUpperCase()).update({
      'player2': {'uid': myUid, 'name': myName, 'color': 'b'},
      'status': 'playing',
    });
    return true;
  }

  // Returns valid moves for piece at [from].
  // Each move: {'to': targetIndex, 'captured': capturedIndex or -1}
  List<Map<String, int>> validMoves(
      List<String> board, int from, int chainJump) {
    if (from < 0 || from >= 64 || board[from].isEmpty) return [];
    if (chainJump >= 0 && chainJump != from) return [];

    final piece = board[from];
    final row = from ~/ 8;
    final col = from % 8;
    final isWhite = piece == 'w' || piece == 'W';
    final isKing = piece == 'W' || piece == 'B';

    // Regular moves: only forward directions (kings go all 4)
    final moveDirs = <List<int>>[];
    if (isWhite || isKing) moveDirs.addAll([[-1, -1], [-1, 1]]);
    if (!isWhite || isKing) moveDirs.addAll([[1, -1], [1, 1]]);

    // Captures: always all 4 directions (Russian shashki rule —
    // regular pieces may capture backward)
    const jumpDirs = [
      [-1, -1], [-1, 1], [1, -1], [1, 1]
    ];

    final jumps = <Map<String, int>>[];
    final moves = <Map<String, int>>[];

    // --- jumps (all directions) ---
    for (final d in jumpDirs) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      final ni = nr * 8 + nc;
      if (board[ni].isEmpty) continue;
      final isEnemy = isWhite
          ? (board[ni] == 'b' || board[ni] == 'B')
          : (board[ni] == 'w' || board[ni] == 'W');
      if (!isEnemy) continue;
      final jr = nr + d[0], jc = nc + d[1];
      if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8) {
        final ji = jr * 8 + jc;
        if (board[ji].isEmpty) {
          jumps.add({'to': ji, 'captured': ni});
        }
      }
    }

    if (jumps.isNotEmpty) return jumps;
    if (chainJump >= 0) return []; // chain continues only via jumps

    // --- regular moves (forward only) ---
    for (final d in moveDirs) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      final ni = nr * 8 + nc;
      if (board[ni].isEmpty) {
        moves.add({'to': ni, 'captured': -1});
      }
    }

    // Mandatory capture rule: if any piece of this color can jump, must jump
    final color = isWhite ? 'w' : 'b';
    if (_anyJump(board, color)) return [];

    return moves;
  }

  bool _anyJump(List<String> board, String color) {
    for (int i = 0; i < 64; i++) {
      if (board[i].isEmpty) continue;
      if (board[i].toLowerCase() != color) continue;
      if (_jumpsFor(board, i).isNotEmpty) return true;
    }
    return false;
  }

  // Returns landing squares available for a jump from [from].
  // Uses all 4 directions so chain-jumps work correctly.
  List<int> _jumpsFor(List<String> board, int from) {
    final row = from ~/ 8, col = from % 8;
    final piece = board[from];
    final isWhite = piece == 'w' || piece == 'W';

    const dirs = [
      [-1, -1], [-1, 1], [1, -1], [1, 1]
    ];

    final result = <int>[];
    for (final d in dirs) {
      final nr = row + d[0], nc = col + d[1];
      if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) continue;
      final ni = nr * 8 + nc;
      if (board[ni].isEmpty) continue;
      final isEnemy = isWhite
          ? (board[ni] == 'b' || board[ni] == 'B')
          : (board[ni] == 'w' || board[ni] == 'W');
      if (!isEnemy) continue;
      final jr = nr + d[0], jc = nc + d[1];
      if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8 &&
          board[jr * 8 + jc].isEmpty) {
        result.add(jr * 8 + jc);
      }
    }
    return result;
  }

  Future<void> makeMove(
      String roomCode, int from, Map<String, int> move) async {
    final ref = _db.collection('checkers').doc(roomCode);
    final doc = await ref.get();
    final data = doc.data()!;

    final board = List<String>.from(data['board']);
    final currentTurn = data['currentTurn'] as String;
    final p1Uid = data['player1']['uid'];
    final myColor = myUid == p1Uid ? 'w' : 'b';

    if (currentTurn != myColor) return;

    final to = move['to']!;
    final captured = move['captured']!;

    board[to] = board[from];
    board[from] = '';
    if (captured >= 0) board[captured] = '';

    // King promotion
    if (board[to] == 'w' && to ~/ 8 == 0) board[to] = 'W';
    if (board[to] == 'b' && to ~/ 8 == 7) board[to] = 'B';

    // Chain jump: check if this piece can jump again (all 4 dirs)
    int chainJump = -1;
    if (captured >= 0 && _jumpsFor(board, to).isNotEmpty) {
      chainJump = to;
    }

    // Piece count check
    final wc = board.where((p) => p == 'w' || p == 'W').length;
    final bc = board.where((p) => p == 'b' || p == 'B').length;
    String? winner;
    if (wc == 0) winner = 'b';
    if (bc == 0) winner = 'w';

    final nextTurn =
        chainJump >= 0 ? currentTurn : (currentTurn == 'w' ? 'b' : 'w');

    // Stalemate: if the next player has no valid moves, current player wins
    if (winner == null && chainJump < 0) {
      bool nextHasMoves = false;
      for (int i = 0; i < 64 && !nextHasMoves; i++) {
        if (board[i].isNotEmpty &&
            board[i].toLowerCase() == nextTurn &&
            validMoves(board, i, -1).isNotEmpty) {
          nextHasMoves = true;
        }
      }
      if (!nextHasMoves) winner = currentTurn;
    }

    await ref.update({
      'board': board,
      'currentTurn': nextTurn,
      'chainJump': chainJump,
      'winner': winner,
      'status': winner != null ? 'finished' : 'playing',
      // Both players see where the last move was made
      'lastMove': {'from': from, 'to': to},
    });
  }

  Stream<DocumentSnapshot> gameStream(String roomCode) =>
      _db.collection('checkers').doc(roomCode).snapshots();

  Future<void> sendMessage(String roomCode, String text) async {
    await _db
        .collection('checkers')
        .doc(roomCode)
        .collection('messages')
        .add({
      'uid': myUid,
      'name': myName,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> messagesStream(String roomCode) => _db
      .collection('checkers')
      .doc(roomCode)
      .collection('messages')
      .orderBy('sentAt')
      .snapshots();

  Future<void> deleteRoom(String roomCode) =>
      _db.collection('checkers').doc(roomCode).delete();
}
