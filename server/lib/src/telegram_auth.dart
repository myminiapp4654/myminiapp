import 'dart:convert';

import 'package:crypto/crypto.dart';

class TelegramUserData {
  final int id;
  final String name;
  final String? username;

  TelegramUserData({required this.id, required this.name, this.username});
}

/// Telegram Mini App'dan kelgan initData'ni bot tokeni bilan tekshiradi.
/// https://core.telegram.org/bots/webapps#validating-data-received-via-the-mini-app
///
/// Haqiqiy bo'lsa foydalanuvchini qaytaradi, aks holda null.
TelegramUserData? validateInitData(
  String initData,
  String botToken, {
  Duration maxAge = const Duration(days: 7),
  DateTime? now,
}) {
  if (initData.isEmpty || botToken.isEmpty) return null;

  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(initData);
  } catch (_) {
    return null;
  }

  final hash = params['hash'];
  if (hash == null) return null;

  final keys = params.keys.where((k) => k != 'hash').toList()..sort();
  final dataCheckString = keys.map((k) => '$k=${params[k]}').join('\n');

  final secretKey =
      Hmac(sha256, utf8.encode('WebAppData')).convert(utf8.encode(botToken));
  final computed =
      Hmac(sha256, secretKey.bytes).convert(utf8.encode(dataCheckString));

  if (!_constantTimeEquals(computed.toString(), hash.toLowerCase())) {
    return null;
  }

  final authDate = int.tryParse(params['auth_date'] ?? '');
  if (authDate == null) return null;
  final issued = DateTime.fromMillisecondsSinceEpoch(authDate * 1000);
  if ((now ?? DateTime.now()).difference(issued) > maxAge) return null;

  final userJson = params['user'];
  if (userJson == null) return null;
  try {
    final u = jsonDecode(userJson) as Map<String, dynamic>;
    final id = u['id'] as int;
    final first = (u['first_name'] as String?)?.trim() ?? '';
    final last = (u['last_name'] as String?)?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return TelegramUserData(
      id: id,
      name: name.isEmpty ? 'Mehmon' : name,
      username: u['username'] as String?,
    );
  } catch (_) {
    return null;
  }
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
