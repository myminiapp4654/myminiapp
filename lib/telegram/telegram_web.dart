import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'telegram_stub.dart' show TelegramUser;

export 'telegram_stub.dart' show TelegramUser;

/// Veb uchun: window.Telegram.WebApp orqali ishlaydi.
/// https://core.telegram.org/bots/webapps
class Telegram {
  Telegram._();

  static JSObject? get _webApp {
    final tg = globalContext['Telegram'];
    if (tg == null || !tg.isA<JSObject>()) return null;
    final app = (tg as JSObject)['WebApp'];
    if (app == null || !app.isA<JSObject>()) return null;
    return app as JSObject;
  }

  static JSObject? get _initDataUnsafe {
    final data = _webApp?['initDataUnsafe'];
    if (data == null || !data.isA<JSObject>()) return null;
    return data as JSObject;
  }

  /// Ilova haqiqatan Telegram ichida ochilganmi.
  /// Oddiy brauzerda ham skript yuklanadi, lekin initData bo'sh bo'ladi.
  static bool get isAvailable {
    final initData = _webApp?['initData'];
    if (initData == null || !initData.isA<JSString>()) return false;
    return (initData as JSString).toDart.isNotEmpty;
  }

  static TelegramUser? get user {
    if (!isAvailable) return null;
    final u = _initDataUnsafe?['user'];
    if (u == null || !u.isA<JSObject>()) return null;
    final obj = u as JSObject;
    final id = (obj['id'] as JSNumber?)?.toDartInt;
    final firstName = (obj['first_name'] as JSString?)?.toDart;
    if (id == null || firstName == null) return null;
    return TelegramUser(
      id: id,
      firstName: firstName,
      lastName: (obj['last_name'] as JSString?)?.toDart,
      username: (obj['username'] as JSString?)?.toDart,
    );
  }

  /// Server tekshiradigan imzolangan ma'lumot (Telegram ichida bo'lmasa null).
  static String? get initData {
    if (!isAvailable) return null;
    return (_webApp!['initData'] as JSString).toDart;
  }

  /// t.me/bot/app?startapp=XXXX havolasidagi XXXX qismi.
  static String? get startParam {
    if (!isAvailable) return null;
    final p = _initDataUnsafe?['start_param'];
    if (p == null || !p.isA<JSString>()) return null;
    final value = (p as JSString).toDart;
    return value.isEmpty ? null : value;
  }

  /// Telegram'ga ilova tayyor ekanini aytadi, to'liq ekranga yoyadi
  /// va ranglarni ilova dizayniga moslaydi.
  static void init() {
    final app = _webApp;
    if (app == null || !isAvailable) return;
    try {
      app.callMethod('ready'.toJS);
      app.callMethod('expand'.toJS);
      app.callMethod('setHeaderColor'.toJS, '#1B1446'.toJS);
      app.callMethod('setBackgroundColor'.toJS, '#1B1446'.toJS);
      // Tasodifan pastga surib ilovani yopib qo'ymaslik uchun
      app.callMethod('disableVerticalSwipes'.toJS);
    } catch (_) {
      // Eski Telegram versiyalarida ba'zi metodlar yo'q — muhim emas.
    }
  }

  /// Yengil tebranish (tugma bosilganda).
  static void haptic() {
    try {
      final h = _webApp?['HapticFeedback'];
      if (h == null || !h.isA<JSObject>()) return;
      (h as JSObject).callMethod('impactOccurred'.toJS, 'light'.toJS);
    } catch (_) {}
  }

  /// t.me havolasini Telegram ichida ochadi (masalan, do'stga ulashish).
  static void openLink(String url) {
    try {
      _webApp?.callMethod('openTelegramLink'.toJS, url.toJS);
    } catch (_) {}
  }
}
