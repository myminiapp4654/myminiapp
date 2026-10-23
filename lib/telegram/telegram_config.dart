/// Telegram bot sozlamalari.
///
/// @BotFather'da bot va Mini App yaratgach, shu ikkisini to'ldiring:
///   /newbot   -> bot username (masalan: oyinim_bot)
///   /newapp   -> Mini App qisqa nomi (masalan: play)
/// Shunda do'stga yuboriladigan havola: https://t.me/oyinim_bot/play?startapp=KOD
const String kTelegramBotUsername = 'oyinim_bot';
const String kTelegramAppShortName = 'play';

String telegramRoomLink(String roomCode) =>
    'https://t.me/$kTelegramBotUsername/$kTelegramAppShortName?startapp=$roomCode';
