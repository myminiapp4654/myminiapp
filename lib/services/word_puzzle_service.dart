import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/word_puzzle_data.dart';

class WordPuzzleService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  List<String> _buildTiles(List words) {
    final needed = <String>{};
    for (final w in words) {
      final word = w['word'] as String;
      if (word.isEmpty) continue;
      for (final ch in word.split('')) {
        needed.add(ch);
      }
    }
    const all = 'ABCDEFGHIJKLMNOPRSTUVYZ';
    final extra = all.split('').where((c) => !needed.contains(c)).toList()
      ..shuffle();
    final tiles = [...needed];
    final fill = 20 - tiles.length;
    if (fill > 0) tiles.addAll(extra.take(fill));
    tiles.shuffle();
    return tiles;
  }

  Future<int> getUserLevel() async {
    final doc = await _db.collection('users').doc(myUid).get();
    if (!doc.exists) return 0;
    return (doc.data()?['wordPuzzleLevel'] as int?) ?? 0;
  }

  Future<void> _saveLevel(String uid, int level) => _db
      .collection('users')
      .doc(uid)
      .set({'wordPuzzleLevel': level}, SetOptions(merge: true));

  Future<String> createRoom({int level = 0}) async {
    final code = _genCode();
    final effectiveLevel = level.clamp(0, kWordPuzzles.length - 1);
    final puzzle = kWordPuzzles[effectiveLevel];
    final tiles = _buildTiles(puzzle['words'] as List);

    await _db.collection('word_puzzle').doc(code).set({
      'roomCode': code,
      'puzzle': puzzle,
      'letterTiles': tiles,
      'revealedLetters': <String>[],
      'wrongLetters': <String>[],
      'currentTurn': myUid,
      'player1': {'uid': myUid, 'name': myName},
      'player2': null,
      'status': 'waiting',
      'result': null,
      'level': effectiveLevel,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> nextLevel(String roomCode, int newLevel) async {
    if (newLevel >= kWordPuzzles.length) return;
    final puzzle = kWordPuzzles[newLevel];
    final tiles = _buildTiles(puzzle['words'] as List);

    await _db.collection('word_puzzle').doc(roomCode).update({
      'puzzle': puzzle,
      'letterTiles': tiles,
      'revealedLetters': <String>[],
      'wrongLetters': <String>[],
      'currentTurn': myUid,
      'status': 'playing',
      'result': null,
      'level': newLevel,
    });
  }

  Future<bool> joinRoom(String code) async {
    final doc =
        await _db.collection('word_puzzle').doc(code.toUpperCase()).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    if (data['status'] != 'waiting') return false;
    if (data['player1']['uid'] == myUid) return false;
    await _db.collection('word_puzzle').doc(code.toUpperCase()).update({
      'player2': {'uid': myUid, 'name': myName},
      'status': 'playing',
    });
    return true;
  }

  Future<void> pickLetter(String roomCode, String letter) async {
    final ref = _db.collection('word_puzzle').doc(roomCode);
    final doc = await ref.get();
    final data = doc.data()!;

    if (data['status'] != 'playing') return;
    if (data['currentTurn'] != myUid) return;

    final revealed = List<String>.from(data['revealedLetters']);
    final wrong = List<String>.from(data['wrongLetters']);
    if (revealed.contains(letter) || wrong.contains(letter)) return;

    final words = (data['puzzle']['words'] as List)
        .map((w) => (w as Map)['word'] as String)
        .where((w) => w.isNotEmpty)
        .toList();

    final isCorrect = words.any((w) => w.contains(letter));

    final p1uid = data['player1']['uid'] as String;
    final p2uid = data['player2']?['uid'] as String?;
    final nextUid = (data['currentTurn'] == p1uid)
        ? (p2uid ?? p1uid)
        : p1uid;

    if (isCorrect) {
      revealed.add(letter);
    } else {
      wrong.add(letter);
    }

    final allLetters = words.join().split('').toSet();
    final isWin = allLetters.isNotEmpty && allLetters.every((l) => revealed.contains(l));
    final isLose = wrong.length >= 5;

    await ref.update({
      'revealedLetters': revealed,
      'wrongLetters': wrong,
      'currentTurn': nextUid,
      'status': (isWin || isLose) ? 'finished' : 'playing',
      'result': isWin ? 'win' : (isLose ? 'lose' : null),
    });

    if (isWin || isLose) {
      await _awardStars(p1uid, 10);
      if (p2uid != null) await _awardStars(p2uid, 10);
    }
    if (isWin) {
      final currentLevel = (data['level'] as int?) ?? 0;
      final nextLevel = currentLevel + 1;
      await _saveLevel(p1uid, nextLevel);
      if (p2uid != null) await _saveLevel(p2uid, nextLevel);
    }
  }

  Future<void> revealWithStar(String roomCode) async {
    final ref = _db.collection('word_puzzle').doc(roomCode);
    final doc = await ref.get();
    final data = doc.data()!;
    if (data['status'] != 'playing') return;

    final revealed = List<String>.from(data['revealedLetters']);
    final wrong = List<String>.from(data['wrongLetters']);
    final words = (data['puzzle']['words'] as List)
        .map((w) => (w as Map)['word'] as String)
        .where((w) => w.isNotEmpty)
        .toList();

    final allLetters = words.join().split('').toSet().toList();
    final unrevealed = allLetters
        .where((l) => !revealed.contains(l) && !wrong.contains(l))
        .toList()
      ..shuffle();

    if (unrevealed.isEmpty) return;

    revealed.add(unrevealed.first);
    final isWin = words.join().split('').toSet().every((l) => revealed.contains(l));

    final update = <String, dynamic>{'revealedLetters': revealed};
    if (isWin) {
      update['status'] = 'finished';
      update['result'] = 'win';
    }
    await ref.update(update);

    if (isWin) {
      final p1uid = data['player1']['uid'] as String;
      final p2uid = data['player2']?['uid'] as String?;
      await _awardStars(p1uid, 10);
      if (p2uid != null) await _awardStars(p2uid, 10);
      final currentLevel = (data['level'] as int?) ?? 0;
      final nextLvl = currentLevel + 1;
      await _saveLevel(p1uid, nextLvl);
      if (p2uid != null) await _saveLevel(p2uid, nextLvl);
    }
  }

  Future<void> _awardStars(String uid, int count) => _db
      .collection('user_stars')
      .doc(uid)
      .set({'stars': FieldValue.increment(count)}, SetOptions(merge: true));

  Stream<DocumentSnapshot> gameStream(String roomCode) =>
      _db.collection('word_puzzle').doc(roomCode).snapshots();

  Future<void> deleteRoom(String roomCode) =>
      _db.collection('word_puzzle').doc(roomCode).delete();
}
