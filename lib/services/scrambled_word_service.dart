import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScrambledWordService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Foydalanuvchi';

  static const _words = [
    {'word': 'PALOV', 'hint': 'Guruchdan taom'},
    {'word': 'SOMSA', 'hint': 'Tandirda pishadi'},
    {'word': 'MANTI', 'hint': 'Bug\'langan taom'},
    {'word': 'LAGMON', 'hint': 'Makaron taomi'},
    {'word': 'TARVUZ', 'hint': 'Yozning mevasi'},
    {'word': 'GILOS', 'hint': 'Qizil yozgi meva'},
    {'word': 'ANOR', 'hint': 'Donali meva'},
    {'word': 'KITOB', 'hint': 'O\'qish uchun'},
    {'word': 'QALAM', 'hint': 'Yozish asbobi'},
    {'word': 'BAHOR', 'hint': 'Gullar ochiladigan fasl'},
    {'word': 'YULDUZ', 'hint': 'Kechasi osmondan ko\'rinadi'},
    {'word': 'DARYO', 'hint': 'Suv oqib o\'tadi'},
    {'word': 'SHAHAR', 'hint': 'Ko\'p odam yashaydigan joy'},
    {'word': 'DARAXT', 'hint': 'O\'rmonda ko\'p bo\'ladi'},
    {'word': 'QUYOSH', 'hint': 'Kunduzi isitadi'},
    {'word': 'BULUT', 'hint': 'Yomg\'ir yog\'diradi'},
    {'word': 'DAFTAR', 'hint': 'Maktabda ishlatiladi'},
    {'word': 'DERAZA', 'hint': 'Uyning ko\'zi'},
    {'word': 'MAKTAB', 'hint': 'Bolalar o\'qiydi'},
    {'word': 'UZUM', 'hint': 'Tokda o\'sadi'},
    {'word': 'LOLA', 'hint': 'Bahorgi qizil gul'},
    {'word': 'OLMA', 'hint': 'Qizil yoki yashil meva'},
    {'word': 'KURSI', 'hint': 'Unga o\'tiriladi'},
    {'word': 'STOL', 'hint': 'Unga ovqat qo\'yiladi'},
    {'word': 'SHASHLIK', 'hint': 'Go\'shtdan taom'},
    {'word': 'QOVUN', 'hint': 'Sariq mazali meva'},
    {'word': 'OLCHA', 'hint': 'Kichik qizil meva'},
    {'word': 'SABZI', 'hint': 'To\'q sariq sabzavot'},
    {'word': 'PIYOZ', 'hint': 'Taomga qo\'shiladi'},
    {'word': 'QOSHIQ', 'hint': 'Quloq uchun zavq'},
  ];

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<String> createRoom() async {
    final code = _generateCode();
    final wordData = _words[Random().nextInt(_words.length)];
    final word = wordData['word']!;
    final letters = word.split('')..shuffle();

    await _db.collection('games_scramble').doc(code).set({
      'word': word,
      'hint': wordData['hint'],
      'letters': letters,
      'slots': List<String>.filled(word.length, ''),
      'player1': {'uid': myUid, 'name': myName},
      'player2': null,
      'status': 'waiting',
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<void> joinRoom(String code) async {
    await _db.collection('games_scramble').doc(code).update({
      'player2': {'uid': myUid, 'name': myName},
      'status': 'playing',
    });
  }

  Stream<DocumentSnapshot> gameStream(String code) =>
      _db.collection('games_scramble').doc(code).snapshots();

  Future<void> placeLetter(String code, int slotIndex, String letter) async {
    final snap = await _db.collection('games_scramble').doc(code).get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final slots = List<String>.from(data['slots']);
    final word = data['word'] as String;

    if (slots[slotIndex].isNotEmpty) return;
    if (word[slotIndex] != letter) return;

    slots[slotIndex] = letter;
    final isComplete = slots.every((s) => s.isNotEmpty);

    await _db.collection('games_scramble').doc(code).update({
      'slots': slots,
      if (isComplete) 'status': 'finished',
      if (isComplete) 'winner': 'both',
    });
  }

  Future<void> playAgain(String code) async {
    final wordData = _words[Random().nextInt(_words.length)];
    final word = wordData['word']!;
    final letters = word.split('')..shuffle();

    await _db.collection('games_scramble').doc(code).update({
      'word': word,
      'hint': wordData['hint'],
      'letters': letters,
      'slots': List<String>.filled(word.length, ''),
      'status': 'playing',
      'winner': null,
    });
  }

  Future<void> deleteRoom(String code) async {
    await _db.collection('games_scramble').doc(code).delete();
  }
}
