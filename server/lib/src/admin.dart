import 'context.dart';
import 'store.dart';

/// Faqat admin uchun amallar (ilovadagi "Foydalanuvchilar" sahifasi).
Map<String, Handler> adminHandlers(Set<String> adminIds) => {
      'admin.users': (c, p) => _users(c, adminIds),
    };

bool isAdminUid(String uid, Set<String> adminIds) =>
    uid.startsWith('tg') && adminIds.contains(uid.substring(2));

/// Botga kirganlar va o'yinni ochganlar ro'yxati.
Object? _users(Ctx c, Set<String> adminIds) {
  if (!isAdminUid(c.uid, adminIds)) throw GameError("Faqat admin uchun");
  final bot = [
    for (final p in c.db.pathsIn('botusers')) c.db.get(p)!,
  ]..sort((a, b) => ((b['last'] as int?) ?? 0).compareTo((a['last'] as int?) ?? 0));
  final app = [
    for (final p in c.db.pathsIn('users')) c.db.get(p)!,
  ]..sort((a, b) => ((b['last'] as int?) ?? 0).compareTo((a['last'] as int?) ?? 0));
  return {
    'bot': bot,
    'app': [
      for (final u in app) {'uid': u['uid'], 'name': u['name'], 'first': u['first'], 'last': u['last']},
    ],
    'now': DateTime.now().millisecondsSinceEpoch,
  };
}
