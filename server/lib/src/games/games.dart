import 'dart:math';

import 'package:oyinim_core/oyinim_core.dart';

import '../context.dart';
import '../store.dart';

// Kolleksiya nomlari (mijozdagi topic nomlari ham shular)
const kTicTacToe = 'games';
const kCheckers = 'checkers';
const kQuiz = 'quiz_rooms';
const kHaYoq = 'ha_yoq_rooms';
const kWordPuzzle = 'word_puzzle';
const kScramble = 'games_scramble';

final _rnd = Random();

/// Ikki o'yinchili o'yinlarda: [uid] shu o'yinda qatnashadimi.
bool _isTwoPlayerMember(Map<String, dynamic> d, String uid) =>
    (d['player1'] as Map?)?['uid'] == uid ||
    (d['player2'] as Map?)?['uid'] == uid;

/// Ko'p o'yinchili o'yinlarda (quiz, ha/yo'q).
bool _isPlayersMember(Map<String, dynamic> d, String uid) =>
    (d['players'] as Map?)?.containsKey(uid) ?? false;

Map<String, dynamic> _requirePlayer(
    Ctx c, String collection, String code) {
  final d = c.db.require('$collection/$code');
  final member = d.containsKey('players')
      ? _isPlayersMember(d, c.uid)
      : _isTwoPlayerMember(d, c.uid);
  if (!member) throw GameError("Siz bu o'yinda emassiz");
  return d;
}

/// Ikki o'yinchili o'yinga ikkinchi o'yinchi bo'lib qo'shilish.
bool _joinTwoPlayer(Ctx c, String collection, String code,
    Map<String, dynamic> player2) {
  final path = '$collection/$code';
  final d = c.db.get(path);
  if (d == null) return false;
  if (_isTwoPlayerMember(d, c.uid)) return true;
  if (d['status'] != 'waiting' || d['player2'] != null) return false;
  d['player2'] = player2;
  d['status'] = 'playing';
  c.db.set(path, d);
  return true;
}

/// O'yinni o'chirish: faqat qatnashchi, faqat tugamagan bo'lsa yaratuvchi.
void _deleteGame(Ctx c, String collection, String code) {
  final path = '$collection/$code';
  final d = c.db.get(path);
  if (d == null) return;
  final member = d.containsKey('players')
      ? _isPlayersMember(d, c.uid)
      : _isTwoPlayerMember(d, c.uid);
  if (member) c.db.delete(path);
}

// =====================================================================
// X-O (5 tasi bir qatorda)
// =====================================================================

String createTicTacToe(Ctx c, int gridSize) {
  final size = gridSize == 12 ? 12 : 10;
  final code = c.db.newCode(kTicTacToe);
  c.db.set('$kTicTacToe/$code', {
    'roomCode': code,
    'gridSize': size,
    'board': List.filled(size * size, ''),
    'currentTurn': 'X',
    'player1': {'uid': c.uid, 'name': c.name, 'symbol': 'X'},
    'player2': null,
    'status': 'waiting',
    'winner': null,
    'scoreX': 0,
    'scoreO': 0,
    'winningCells': <int>[],
  });
  return code;
}

bool joinTicTacToe(Ctx c, String code) => _joinTwoPlayer(
    c, kTicTacToe, code, {'uid': c.uid, 'name': c.name, 'symbol': 'O'});

void _tttMove(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kTicTacToe, code);
  if (d['status'] != 'playing') return;

  final gridSize = (d['gridSize'] as int?) ?? 10;
  final index = pInt(p, 'index', min: 0, max: gridSize * gridSize - 1);
  final board = List<String>.from(d['board'] as List);
  final mySymbol = (d['player1'] as Map)['uid'] == c.uid ? 'X' : 'O';

  if (d['currentTurn'] != mySymbol) return;
  if (board[index].isNotEmpty) return;

  board[index] = mySymbol;

  final newLines =
      TicTacToeRules.findNewLines(board, gridSize, index, mySymbol);
  final winningCells = List<int>.from(d['winningCells'] as List? ?? []);
  var scoreX = (d['scoreX'] as int?) ?? 0;
  var scoreO = (d['scoreO'] as int?) ?? 0;
  for (final line in newLines) {
    winningCells.addAll(line);
    if (mySymbol == 'X') {
      scoreX++;
    } else {
      scoreO++;
    }
  }

  String? winner;
  var status = 'playing';
  if (!board.contains('')) {
    status = 'finished';
    winner = scoreX > scoreO ? 'X' : (scoreO > scoreX ? 'O' : 'draw');
  }

  c.db.set('$kTicTacToe/$code', {
    ...d,
    'board': board,
    'currentTurn': mySymbol == 'X' ? 'O' : 'X',
    'winningCells': winningCells,
    'scoreX': scoreX,
    'scoreO': scoreO,
    'winner': winner,
    'status': status,
  });
}

// =====================================================================
// Shashka
// =====================================================================

String createCheckers(Ctx c) {
  final code = c.db.newCode(kCheckers);
  c.db.set('$kCheckers/$code', {
    'roomCode': code,
    'board': CheckersRules.initialBoard(),
    'currentTurn': 'w',
    'player1': {'uid': c.uid, 'name': c.name, 'color': 'w'},
    'player2': null,
    'status': 'waiting',
    'winner': null,
    'chainJump': -1,
    'lastMove': null,
  });
  return code;
}

bool joinCheckers(Ctx c, String code) => _joinTwoPlayer(
    c, kCheckers, code, {'uid': c.uid, 'name': c.name, 'color': 'b'});

void _checkersMove(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kCheckers, code);
  if (d['status'] != 'playing') return;

  final from = pInt(p, 'from', min: 0, max: 63);
  final to = pInt(p, 'to', min: 0, max: 63);
  final board = List<String>.from(d['board'] as List);
  final currentTurn = d['currentTurn'] as String;
  final myColor = (d['player1'] as Map)['uid'] == c.uid ? 'w' : 'b';
  final chainJump = (d['chainJump'] as int?) ?? -1;

  if (currentTurn != myColor) return;
  if (board[from].toLowerCase() != myColor) return;

  // Yurish qoidaga mosligini serverda tekshiramiz
  final move = CheckersRules.validMoves(board, from, chainJump)
      .where((m) => m['to'] == to)
      .firstOrNull;
  if (move == null) throw GameError("Bunday yurish mumkin emas");
  final captured = move['captured']!;

  board[to] = board[from];
  board[from] = '';
  if (captured >= 0) board[captured] = '';

  if (board[to] == 'w' && to ~/ 8 == 0) board[to] = 'W';
  if (board[to] == 'b' && to ~/ 8 == 7) board[to] = 'B';

  var nextChain = -1;
  if (captured >= 0 && CheckersRules.jumpsFor(board, to).isNotEmpty) {
    nextChain = to;
  }

  final wc = board.where((x) => x == 'w' || x == 'W').length;
  final bc = board.where((x) => x == 'b' || x == 'B').length;
  String? winner;
  if (wc == 0) winner = 'b';
  if (bc == 0) winner = 'w';

  final nextTurn =
      nextChain >= 0 ? currentTurn : (currentTurn == 'w' ? 'b' : 'w');

  // Raqibning yurishi qolmasa — joriy o'yinchi g'olib
  if (winner == null &&
      nextChain < 0 &&
      !CheckersRules.hasAnyMove(board, nextTurn)) {
    winner = currentTurn;
  }

  c.db.set('$kCheckers/$code', {
    ...d,
    'board': board,
    'currentTurn': nextTurn,
    'chainJump': nextChain,
    'winner': winner,
    'status': winner != null ? 'finished' : 'playing',
    'lastMove': {'from': from, 'to': to},
  });
}

// =====================================================================
// Viktorina
// =====================================================================

const _quizSeconds = 15;

String createQuiz(Ctx c, int count) {
  final code = c.db.newCode(kQuiz);
  final questions = List.of(kQuestions)..shuffle(_rnd);
  c.db.set('$kQuiz/$code', {
    'roomCode': code,
    'host': {'uid': c.uid, 'name': c.name},
    'questions': questions.take(count.clamp(1, kQuestions.length)).toList(),
    'players': {
      c.uid: {'name': c.name, 'score': 0, 'answer': -1},
    },
    'currentQuestion': -1,
    'questionStartedAt': null,
    'status': 'waiting',
  });
  return code;
}

bool joinQuiz(Ctx c, String code) {
  final path = '$kQuiz/$code';
  final d = c.db.get(path);
  if (d == null) return false;
  final players = d['players'] as Map<String, dynamic>;
  if (players.containsKey(c.uid)) return true;
  if (d['status'] != 'waiting' || players.length >= 8) return false;
  players[c.uid] = {'name': c.name, 'score': 0, 'answer': -1};
  c.db.set(path, d);
  return true;
}

void _quizStart(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kQuiz, code);
  if ((d['host'] as Map)['uid'] != c.uid) return;
  if (d['status'] != 'waiting') return;
  c.db.set('$kQuiz/$code', {
    ...d,
    'currentQuestion': 0,
    'questionStartedAt': DateTime.now().millisecondsSinceEpoch,
    'status': 'playing',
  });
}

void _quizAnswer(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kQuiz, code);
  if (d['status'] != 'playing') return;

  final questions = d['questions'] as List;
  final qi = d['currentQuestion'] as int;
  if (qi < 0 || qi >= questions.length) return;

  final q = questions[qi] as Map;
  final options = q['o'] as List;
  final index = pInt(p, 'index', min: 0, max: options.length - 1);

  final players = d['players'] as Map<String, dynamic>;
  final me = players[c.uid] as Map<String, dynamic>;
  if (me['answer'] != -1) return;

  // Ball serverda hisoblanadi: qancha tez javob bersa, shuncha ko'p
  final started = (d['questionStartedAt'] as int?) ?? 0;
  final elapsed =
      (DateTime.now().millisecondsSinceEpoch - started) ~/ 1000;
  final secondsLeft = (_quizSeconds - elapsed).clamp(0, _quizSeconds);
  final correct = index == q['c'];

  me['answer'] = index;
  me['score'] = ((me['score'] as int?) ?? 0) + (correct ? secondsLeft * 100 : 0);
  c.db.set('$kQuiz/$code', d);
}

void _quizNext(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kQuiz, code);
  if ((d['host'] as Map)['uid'] != c.uid) return;
  if (d['status'] != 'playing') return;

  final current = pInt(p, 'current');
  // Ikki marta bosilsa ham bir savol o'tkazib yuborilmasin
  if (d['currentQuestion'] != current) return;

  final total = (d['questions'] as List).length;
  final next = current + 1;
  if (next >= total) {
    d['currentQuestion'] = next;
    d['status'] = 'finished';
  } else {
    final players = d['players'] as Map<String, dynamic>;
    for (final pl in players.values) {
      (pl as Map)['answer'] = -1;
    }
    d['currentQuestion'] = next;
    d['questionStartedAt'] = DateTime.now().millisecondsSinceEpoch;
  }
  c.db.set('$kQuiz/$code', d);
}

// =====================================================================
// Ha / Yo'q
// =====================================================================

String createHaYoq(Ctx c, int questionCount) {
  final code = c.db.newCode(kHaYoq);
  c.db.set('$kHaYoq/$code', {
    'roomCode': code,
    'host': c.uid,
    'players': {
      c.uid: {'name': c.name},
    },
    'playerOrder': [c.uid],
    'questionCount': questionCount.clamp(1, 20),
    'status': 'waiting',
    'currentAskerIndex': 0,
    'currentAnswererIndex': 1,
    'askedCount': 0,
    'completedRounds': 0,
    'pendingQuestion': null,
    'log': <dynamic>[],
  });
  return code;
}

bool joinHaYoq(Ctx c, String code) {
  final path = '$kHaYoq/$code';
  final d = c.db.get(path);
  if (d == null) return false;
  final players = d['players'] as Map<String, dynamic>;
  if (players.containsKey(c.uid)) return true;
  if (d['status'] != 'waiting' || players.length >= 8) return false;
  players[c.uid] = {'name': c.name};
  (d['playerOrder'] as List).add(c.uid);
  c.db.set(path, d);
  return true;
}

void _haYoqStart(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kHaYoq, code);
  if (d['host'] != c.uid || d['status'] != 'waiting') return;
  if ((d['playerOrder'] as List).length < 2) {
    throw GameError("Kamida 2 o'yinchi kerak");
  }
  c.db.set('$kHaYoq/$code', {...d, 'status': 'playing'});
}

void _haYoqAsk(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final question = pStr(p, 'question', maxLen: 300).trim();
  final d = _requirePlayer(c, kHaYoq, code);
  if (d['status'] != 'playing' || d['pendingQuestion'] != null) return;
  final order = List<String>.from(d['playerOrder'] as List);
  if (order[d['currentAskerIndex'] as int] != c.uid) return;
  c.db.set('$kHaYoq/$code', {...d, 'pendingQuestion': question});
}

void _haYoqAnswer(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final answer = pStr(p, 'answer', maxLen: 20);
  final d = _requirePlayer(c, kHaYoq, code);
  if (d['status'] != 'playing' || d['pendingQuestion'] == null) return;

  final order = List<String>.from(d['playerOrder'] as List);
  final askerIdx = d['currentAskerIndex'] as int;
  final answererIdx = d['currentAnswererIndex'] as int;
  if (order[answererIdx] != c.uid) return;

  final players = d['players'] as Map<String, dynamic>;
  final qCount = d['questionCount'] as int;
  final asked = (d['askedCount'] as int) + 1;
  var completed = d['completedRounds'] as int;

  (d['log'] as List).add({
    'askerUid': order[askerIdx],
    'askerName': (players[order[askerIdx]] as Map)['name'],
    'answererUid': order[answererIdx],
    'answererName': (players[order[answererIdx]] as Map)['name'],
    'question': d['pendingQuestion'],
    'answer': answer,
  });
  d['pendingQuestion'] = null;

  if (asked >= qCount) {
    completed++;
    d['completedRounds'] = completed;
    if (completed >= order.length) {
      d['status'] = 'finished';
      d['askedCount'] = asked;
    } else {
      final nAsker = (askerIdx + 1) % order.length;
      d['currentAskerIndex'] = nAsker;
      d['currentAnswererIndex'] = (nAsker + 1) % order.length;
      d['askedCount'] = 0;
    }
  } else {
    d['askedCount'] = asked;
  }
  c.db.set('$kHaYoq/$code', d);
}

// =====================================================================
// So'z topish (hamkorlikda)
// =====================================================================

Map<String, dynamic> _wordPuzzleState(int level, String turnUid) {
  final puzzle = kWordPuzzles[level];
  return {
    'puzzle': puzzle,
    'letterTiles': WordPuzzleRules.buildTiles(puzzle, _rnd),
    'revealedLetters': <String>[],
    'wrongLetters': <String>[],
    'currentTurn': turnUid,
    'result': null,
    'level': level,
  };
}

String createWordPuzzle(Ctx c) {
  final code = c.db.newCode(kWordPuzzle);
  final level = c.wordPuzzleLevel.clamp(0, kWordPuzzles.length - 1);
  c.db.set('$kWordPuzzle/$code', {
    'roomCode': code,
    ..._wordPuzzleState(level, c.uid),
    'player1': {'uid': c.uid, 'name': c.name},
    'player2': null,
    'status': 'waiting',
  });
  return code;
}

bool joinWordPuzzle(Ctx c, String code) =>
    _joinTwoPlayer(c, kWordPuzzle, code, {'uid': c.uid, 'name': c.name});

void _wordPuzzleFinish(Ctx c, Map<String, dynamic> d, bool win) {
  final p1 = (d['player1'] as Map)['uid'] as String;
  final p2 = (d['player2'] as Map?)?['uid'] as String?;
  for (final uid in [p1, ?p2]) {
    c.addStars(uid, 10);
    if (win) c.setWordPuzzleLevel(uid, ((d['level'] as int?) ?? 0) + 1);
  }
}

void _wordPuzzlePick(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final letter = pStr(p, 'letter', maxLen: 2).toUpperCase();
  final d = _requirePlayer(c, kWordPuzzle, code);
  if (d['status'] != 'playing' || d['currentTurn'] != c.uid) return;

  final revealed = List<String>.from(d['revealedLetters'] as List);
  final wrong = List<String>.from(d['wrongLetters'] as List);
  if (revealed.contains(letter) || wrong.contains(letter)) return;
  if (!(d['letterTiles'] as List).contains(letter)) return;

  final puzzle = d['puzzle'] as Map;
  final isCorrect =
      WordPuzzleRules.wordsOf(puzzle).any((w) => w.contains(letter));
  if (isCorrect) {
    revealed.add(letter);
  } else {
    wrong.add(letter);
  }

  final p1 = (d['player1'] as Map)['uid'] as String;
  final p2 = (d['player2'] as Map?)?['uid'] as String?;
  final isWin = WordPuzzleRules.isSolved(puzzle, revealed);
  final isLose = !isWin && wrong.length >= WordPuzzleRules.maxWrong;

  d['revealedLetters'] = revealed;
  d['wrongLetters'] = wrong;
  d['currentTurn'] = c.uid == p1 ? (p2 ?? p1) : p1;
  d['status'] = (isWin || isLose) ? 'finished' : 'playing';
  d['result'] = isWin ? 'win' : (isLose ? 'lose' : null);
  c.db.set('$kWordPuzzle/$code', d);

  if (isWin || isLose) _wordPuzzleFinish(c, d, isWin);
}

/// Yulduz evaziga bitta harfni ochadi. Yulduz yetmasa false.
bool _wordPuzzleReveal(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kWordPuzzle, code);
  if (d['status'] != 'playing') return true;

  final puzzle = d['puzzle'] as Map;
  final revealed = List<String>.from(d['revealedLetters'] as List);
  final wrong = List<String>.from(d['wrongLetters'] as List);
  final hidden = WordPuzzleRules.wordsOf(puzzle)
      .join()
      .split('')
      .toSet()
      .where((l) => !revealed.contains(l) && !wrong.contains(l))
      .toList();
  if (hidden.isEmpty) return true;

  if (!c.spendStar()) return false;

  revealed.add(hidden[_rnd.nextInt(hidden.length)]);
  d['revealedLetters'] = revealed;
  final isWin = WordPuzzleRules.isSolved(puzzle, revealed);
  if (isWin) {
    d['status'] = 'finished';
    d['result'] = 'win';
  }
  c.db.set('$kWordPuzzle/$code', d);
  if (isWin) _wordPuzzleFinish(c, d, true);
  return true;
}

void _wordPuzzleNext(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kWordPuzzle, code);
  if (d['status'] != 'finished') return;
  final current = (d['level'] as int?) ?? 0;
  final wanted = pInt(p, 'level', min: 0);
  // Faqat shu darajani qaytadan yoki keyingisini o'ynash mumkin
  final level = wanted.clamp(0, current + 1);
  if (level >= kWordPuzzles.length) return;
  c.db.set('$kWordPuzzle/$code', {
    ...d,
    ..._wordPuzzleState(level, c.uid),
    'status': 'playing',
  });
}

// =====================================================================
// Harflar (so'z aralash, hamkorlikda)
// =====================================================================

Map<String, dynamic> _scrambleState() {
  final w = kScrambleWords[_rnd.nextInt(kScrambleWords.length)];
  final word = w['word']!;
  return {
    'word': word,
    'hint': w['hint'],
    'letters': word.split('')..shuffle(_rnd),
    'slots': List<String>.filled(word.length, ''),
    'winner': null,
  };
}

String createScramble(Ctx c) {
  final code = c.db.newCode(kScramble);
  c.db.set('$kScramble/$code', {
    'roomCode': code,
    ..._scrambleState(),
    'player1': {'uid': c.uid, 'name': c.name},
    'player2': null,
    'status': 'waiting',
  });
  return code;
}

bool joinScramble(Ctx c, String code) =>
    _joinTwoPlayer(c, kScramble, code, {'uid': c.uid, 'name': c.name});

void _scramblePlace(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kScramble, code);
  if (d['status'] != 'playing') return;
  final word = d['word'] as String;
  final slot = pInt(p, 'slot', min: 0, max: word.length - 1);
  final letter = pStr(p, 'letter', maxLen: 2).toUpperCase();

  final slots = List<String>.from(d['slots'] as List);
  if (slots[slot].isNotEmpty || word[slot] != letter) return;
  slots[slot] = letter;
  final done = slots.every((s) => s.isNotEmpty);
  c.db.set('$kScramble/$code', {
    ...d,
    'slots': slots,
    if (done) 'status': 'finished',
    if (done) 'winner': 'both',
  });
}

void _scrambleAgain(Ctx c, Map<String, dynamic> p) {
  final code = pCode(p);
  final d = _requirePlayer(c, kScramble, code);
  if (d['status'] != 'finished') return;
  c.db.set('$kScramble/$code', {...d, ..._scrambleState(), 'status': 'playing'});
}

// =====================================================================

Map<String, Handler> gameHandlers() => {
      'ttt.move': (c, p) => _tttMove(c, p),
      'ttt.delete': (c, p) => _deleteGame(c, kTicTacToe, pCode(p)),
      'checkers.move': (c, p) => _checkersMove(c, p),
      'checkers.delete': (c, p) => _deleteGame(c, kCheckers, pCode(p)),
      'quiz.start': (c, p) => _quizStart(c, p),
      'quiz.answer': (c, p) => _quizAnswer(c, p),
      'quiz.next': (c, p) => _quizNext(c, p),
      'quiz.delete': (c, p) => _deleteGame(c, kQuiz, pCode(p)),
      'hayoq.start': (c, p) => _haYoqStart(c, p),
      'hayoq.ask': (c, p) => _haYoqAsk(c, p),
      'hayoq.answer': (c, p) => _haYoqAnswer(c, p),
      'hayoq.delete': (c, p) => _deleteGame(c, kHaYoq, pCode(p)),
      'wp.pick': (c, p) => _wordPuzzlePick(c, p),
      'wp.reveal': (c, p) => _wordPuzzleReveal(c, p),
      'wp.next': (c, p) => _wordPuzzleNext(c, p),
      'wp.delete': (c, p) => _deleteGame(c, kWordPuzzle, pCode(p)),
      'scramble.place': (c, p) => _scramblePlace(c, p),
      'scramble.again': (c, p) => _scrambleAgain(c, p),
      'scramble.delete': (c, p) => _deleteGame(c, kScramble, pCode(p)),
    };
