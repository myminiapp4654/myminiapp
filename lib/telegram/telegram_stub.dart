/// Telegram foydalanuvchisi haqida ma'lumot.
class TelegramUser {
  final int id;
  final String firstName;
  final String? lastName;
  final String? username;

  const TelegramUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
  });

  String get fullName =>
      [firstName, if (lastName != null && lastName!.isNotEmpty) lastName]
          .join(' ');
}

/// Android/iOS uchun: ilova Telegram ichida emas, hamma narsa bo'sh.
class Telegram {
  Telegram._();

  static bool get isAvailable => false;
  static TelegramUser? get user => null;
  static String? get startParam => null;
  static String? get initData => null;

  static void init() {}
  static void haptic() {}
  static void openLink(String url) {}
}
