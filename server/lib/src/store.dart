import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// O'yinchiga ko'rsatiladigan xato (masalan, "Xona topilmadi").
class GameError implements Exception {
  final String message;
  GameError(this.message);
  @override
  String toString() => message;
}

typedef DocListener = void Function(String path, Map<String, dynamic>? data);

/// Hujjatlar ombori: "kolleksiya/id" -> JSON.
///
/// Hamma narsa bitta isolate'da ishlaydi, shuning uchun har bir amal
/// boshqasi bilan aralashmaydi (Firestore'dagi tranzaksiyaga ehtiyoj yo'q).
/// O'yin xonalari xotirada turadi; `users` va `scores` faylga saqlanadi.
class Store {
  final _docs = <String, Map<String, dynamic>>{};
  final _touched = <String, DateTime>{};
  final _listeners = <DocListener>[];

  final File? _usersFile;
  final File? _scoresFile;
  final File? _botUsersFile;
  Timer? _saveTimer;
  Timer? _gcTimer;

  /// Shuncha vaqt o'zgarmagan o'yin xonalari o'chiriladi.
  final Duration roomTtl;

  Store({String? dataDir, this.roomTtl = const Duration(hours: 6)})
      : _usersFile = dataDir == null ? null : File('$dataDir/users.json'),
        _scoresFile = dataDir == null ? null : File('$dataDir/scores.json'),
        _botUsersFile = dataDir == null ? null : File('$dataDir/botusers.json') {
    _loadUsers();
    _load(_scoresFile, 'scores');
    _load(_botUsersFile, 'botusers');
    _gcTimer = Timer.periodic(const Duration(minutes: 10), (_) => _gc());
  }

  void addListener(DocListener l) => _listeners.add(l);

  bool exists(String path) => _docs.containsKey(path);

  /// Hujjatning nusxasi (o'zgartirish omborga ta'sir qilmaydi).
  Map<String, dynamic>? get(String path) {
    final d = _docs[path];
    return d == null ? null : _deepCopy(d);
  }

  /// Hujjatni talab qiladi, yo'q bo'lsa xato beradi.
  Map<String, dynamic> require(String path,
      [String message = 'Xona topilmadi']) {
    final d = get(path);
    if (d == null) throw GameError(message);
    return d;
  }

  void set(String path, Map<String, dynamic> data) {
    _docs[path] = _deepCopy(data);
    _touched[path] = DateTime.now();
    _changed(path);
  }

  void delete(String path) {
    if (_docs.remove(path) == null) return;
    _touched.remove(path);
    _changed(path);
  }

  /// Kolleksiyada band bo'lmagan 6 belgili kod.
  String newCode(String collection) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    while (true) {
      final code =
          List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
      if (!_docs.containsKey('$collection/$code')) return code;
    }
  }

  int get docCount => _docs.length;

  /// Kolleksiyadagi barcha hujjat yo'llari (masalan, rooms/ABC123).
  List<String> pathsIn(String collection) =>
      _docs.keys.where((k) => k.startsWith('$collection/')).toList();

  /// Faylga saqlanadigan (va o'chirilmaydigan) kolleksiyalar.
  static bool _persisted(String path) =>
      path.startsWith('users/') || path.startsWith('scores/') || path.startsWith('botusers/');

  void _changed(String path) {
    final data = _docs[path];
    for (final l in _listeners) {
      l(path, data);
    }
    if (_persisted(path)) _scheduleSave();
  }

  void _gc() {
    final cutoff = DateTime.now().subtract(roomTtl);
    final old = _touched.entries
        .where((e) => !_persisted(e.key) && e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    for (final p in old) {
      delete(p);
    }
  }

  // ---- users.json ----

  void _loadUsers() {
    final f = _usersFile;
    if (f == null || !f.existsSync()) return;
    try {
      final all = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      all.forEach((uid, data) {
        _docs['users/$uid'] = Map<String, dynamic>.from(data as Map);
      });
      stdout.writeln('Foydalanuvchilar yuklandi: ${all.length}');
    } catch (e) {
      stderr.writeln('users.json o\'qilmadi: $e');
    }
  }

  /// Kolleksiyani fayldan yuklash: {id: hujjat}.
  void _load(File? f, String collection) {
    if (f == null || !f.existsSync()) return;
    try {
      final all = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      all.forEach((id, data) {
        _docs['$collection/$id'] = Map<String, dynamic>.from(data as Map);
      });
    } catch (e) {
      stderr.writeln("${f.path} o'qilmadi: $e");
    }
  }

  void _save(File? f, String collection) {
    if (f == null) return;
    final out = <String, dynamic>{};
    final prefix = '$collection/';
    _docs.forEach((path, data) {
      if (path.startsWith(prefix)) out[path.substring(prefix.length)] = data;
    });
    try {
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(out));
      tmp.renameSync(f.path);
    } catch (e) {
      stderr.writeln('${f.path} saqlanmadi: $e');
    }
  }

  void _scheduleSave() {
    if (_usersFile == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), saveNow);
  }

  void saveNow() {
    _save(_scoresFile, 'scores');
    _save(_botUsersFile, 'botusers');
    final f = _usersFile;
    if (f == null) return;
    final users = <String, dynamic>{};
    _docs.forEach((path, data) {
      if (path.startsWith('users/')) users[path.substring(6)] = data;
    });
    try {
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp');
      tmp.writeAsStringSync(jsonEncode(users));
      tmp.renameSync(f.path);
    } catch (e) {
      stderr.writeln('users.json saqlanmadi: $e');
    }
  }

  void dispose() {
    _gcTimer?.cancel();
    _saveTimer?.cancel();
    saveNow();
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
}
