import 'dart:math';

/// UNO o'yini mantig'i (Telegram'dan mustaqil, test qilinadi).
///
/// Paluba — 108 karta:
///  - 4 rang × (bitta 0, ikkitadan 1–9, ikkitadan Skip, Reverse, +2) = 100
///  - 4 ta Wild (rang tanlash) va 4 ta Wild +4
///
/// Soddalashtirilgan qoidalar (UNO botlarida odatiy):
///  - +2 va +4 ni ustma-ust qo'yib bo'lmaydi: keyingi o'yinchi oladi va navbati o'tadi
///  - karta olgan o'yinchi olingan kartani darhol tashlashi yoki navbatni o'tkazishi mumkin
///  - 2 kishilik o'yinda Reverse — Skip kabi ishlaydi
///  - oxirgidan oldingi kartani tashlashdan oldin "UNO!" bosilmasa — jarima 2 karta
enum UnoColor { red, yellow, green, blue, wild }

enum UnoKind { number, skip, reverse, draw2, wild, wild4 }

class UnoCard {
  /// Palubadagi yagona raqami (0..107) — tugmalarda shu ishlatiladi.
  final int id;
  final UnoColor color;
  final UnoKind kind;
  final int number; // faqat raqamli kartalar uchun

  const UnoCard(this.id, this.color, this.kind, [this.number = -1]);

  bool get isWild => kind == UnoKind.wild || kind == UnoKind.wild4;

  static const _colorEmoji = {
    UnoColor.red: '🟥',
    UnoColor.yellow: '🟨',
    UnoColor.green: '🟩',
    UnoColor.blue: '🟦',
    UnoColor.wild: '🌈',
  };

  static String colorEmoji(UnoColor c) => _colorEmoji[c]!;

  static String colorName(UnoColor c) => switch (c) {
        UnoColor.red => 'Qizil',
        UnoColor.yellow => 'Sariq',
        UnoColor.green => 'Yashil',
        UnoColor.blue => "Ko'k",
        UnoColor.wild => 'Rangli',
      };

  /// Kartaning qisqa belgisi: "7", "⊘", "⇄", "+2", "Wild", "+4".
  String get face => switch (kind) {
        UnoKind.number => '$number',
        UnoKind.skip => '⊘',
        UnoKind.reverse => '⇄',
        UnoKind.draw2 => '+2',
        UnoKind.wild => 'Wild',
        UnoKind.wild4 => '+4',
      };

  /// Tugma va xabarlar uchun: "🟥 7".
  String get label => '${colorEmoji(color)} $face';

  /// Tartiblash uchun (qo'lda rang bo'yicha guruhlab ko'rsatish).
  int get sortKey => color.index * 100 + kind.index * 10 + max(number, 0);

  @override
  String toString() => label;
}

/// To'liq, tartiblangan 108 kartali paluba.
List<UnoCard> buildDeck() {
  final cards = <UnoCard>[];
  var id = 0;
  for (final c in [UnoColor.red, UnoColor.yellow, UnoColor.green, UnoColor.blue]) {
    cards.add(UnoCard(id++, c, UnoKind.number, 0));
    for (var n = 1; n <= 9; n++) {
      cards.add(UnoCard(id++, c, UnoKind.number, n));
      cards.add(UnoCard(id++, c, UnoKind.number, n));
    }
    for (final k in [UnoKind.skip, UnoKind.reverse, UnoKind.draw2]) {
      cards.add(UnoCard(id++, c, k));
      cards.add(UnoCard(id++, c, k));
    }
  }
  for (var k = 0; k < 4; k++) {
    cards.add(UnoCard(id++, UnoColor.wild, UnoKind.wild));
    cards.add(UnoCard(id++, UnoColor.wild, UnoKind.wild4));
  }
  return cards;
}

class UnoPlayer {
  final int id; // Telegram user id
  final String name;
  final hand = <UnoCard>[];

  /// "UNO!" deb aytdimi (oxirgidan oldingi kartani tashlashdan oldin).
  bool saidUno = false;

  /// Ketma-ket vaqti tugagan navbatlar (AFK).
  int timeouts = 0;

  UnoPlayer(this.id, this.name);
}

enum UnoStatus { lobby, playing, finished }

/// Bir yurish natijasi — guruhga xabar yozish uchun.
class UnoEvent {
  final String text;
  const UnoEvent(this.text);
  @override
  String toString() => text;
}

class UnoGame {
  static const minPlayers = 2;
  static const maxPlayers = 10;
  static const handSize = 7;

  final Random _r;
  UnoStatus status = UnoStatus.lobby;
  final players = <UnoPlayer>[];

  /// O'yinni ochgan foydalanuvchi.
  final int ownerId;

  int turn = 0;
  int direction = 1; // 1 — soat yo'nalishida, -1 — teskari
  final drawPile = <UnoCard>[];
  final discardPile = <UnoCard>[];

  /// Stoldagi joriy rang (Wild tashlanganda tanlangan rang).
  UnoColor currentColor = UnoColor.red;

  /// Navbatdagi o'yinchi shu yurishda karta oldimi (olingan karta).
  UnoCard? drawnThisTurn;

  /// Rang tanlashni kutayotgan Wild (o'yinchi tanlamaguncha navbat o'tmaydi).
  UnoCard? pendingWild;

  UnoPlayer? winner;

  UnoGame({required this.ownerId, Random? random}) : _r = random ?? Random();

  UnoPlayer get current => players[turn];
  UnoCard get top => discardPile.last;

  UnoPlayer? player(int id) => players.where((p) => p.id == id).firstOrNull;

  // ---------------------------------------------------------------- lobby

  bool join(int id, String name) {
    if (status != UnoStatus.lobby || players.length >= maxPlayers || player(id) != null) {
      return false;
    }
    players.add(UnoPlayer(id, name));
    return true;
  }

  bool leave(int id) {
    final p = player(id);
    if (p == null) return false;
    if (status == UnoStatus.playing) {
      // Kartalari palubaning tagiga qaytadi
      drawPile.insertAll(0, p.hand);
      final idx = players.indexOf(p);
      players.removeAt(idx);
      if (players.length < minPlayers) {
        status = UnoStatus.finished;
        winner = players.firstOrNull;
        return true;
      }
      if (idx < turn) turn--;
      if (turn >= players.length) turn = 0;
      drawnThisTurn = null;
      pendingWild = null;
    } else {
      players.remove(p);
    }
    return true;
  }

  /// O'yinni boshlash: aralashtirish, 7 tadan tarqatish, birinchi karta.
  bool start() {
    if (status != UnoStatus.lobby || players.length < minPlayers) return false;
    drawPile
      ..clear()
      ..addAll(buildDeck()..shuffle(_r));
    for (var k = 0; k < handSize; k++) {
      for (final p in players) {
        p.hand.add(drawPile.removeLast());
      }
    }
    // Birinchi karta — raqamli bo'lsin (maxsus kartalar palubaga qaytadi)
    while (true) {
      final c = drawPile.removeLast();
      if (c.kind == UnoKind.number) {
        discardPile.add(c);
        currentColor = c.color;
        break;
      }
      drawPile.insert(_r.nextInt(drawPile.length), c);
    }
    players.shuffle(_r);
    turn = 0;
    status = UnoStatus.playing;
    for (final p in players) {
      _sort(p);
    }
    return true;
  }

  // ---------------------------------------------------------------- qoidalar

  /// Kartani hozir tashlash mumkinmi.
  bool canPlay(UnoCard c) {
    if (c.isWild) return true;
    return c.color == currentColor ||
        (c.kind == top.kind && (c.kind != UnoKind.number || c.number == top.number));
  }

  /// [p] ning hozir tashlashi mumkin bo'lgan kartalari.
  List<UnoCard> playable(UnoPlayer p) {
    if (status != UnoStatus.playing || p != current || pendingWild != null) return const [];
    if (drawnThisTurn != null) {
      return canPlay(drawnThisTurn!) ? [drawnThisTurn!] : const [];
    }
    return [for (final c in p.hand) if (canPlay(c)) c];
  }

  int _next([int steps = 1]) => (turn + direction * steps) % players.length;

  void _advance([int steps = 1]) {
    turn = _next(steps);
    drawnThisTurn = null;
  }

  UnoCard _take() {
    if (drawPile.isEmpty) {
      // Tashlangan kartalar (eng ustidagisidan tashqari) aralashtirilib qaytadi
      final keep = discardPile.removeLast();
      drawPile.addAll(discardPile..shuffle(_r));
      discardPile
        ..clear()
        ..add(keep);
    }
    return drawPile.removeLast();
  }

  /// [p] [n] ta karta oladi (paluba tugasa — tashlanganlar aralashtiriladi).
  List<UnoCard> give(UnoPlayer p, int n) {
    final got = <UnoCard>[];
    for (var k = 0; k < n && drawPile.length + discardPile.length > 1; k++) {
      got.add(_take());
    }
    p.hand.addAll(got);
    p.saidUno = false;
    _sort(p);
    return got;
  }

  void _sort(UnoPlayer p) => p.hand.sort((a, b) => a.sortKey.compareTo(b.sortKey));

  /// "UNO!" — faqat o'z navbatida, qo'lda 2 ta karta bo'lganda.
  bool sayUno(int playerId) {
    final p = player(playerId);
    if (p == null || status != UnoStatus.playing || p != current || p.hand.length != 2) {
      return false;
    }
    p.saidUno = true;
    return true;
  }

  /// Karta tashlash. Wild bo'lsa — [color] kerak (yoki keyin [chooseColor]).
  /// Natija: guruh uchun xabarlar (bo'sh ro'yxat — yurish rad etildi).
  List<UnoEvent> play(int playerId, int cardId, {UnoColor? color}) {
    final p = player(playerId);
    if (p == null || p != current || status != UnoStatus.playing || pendingWild != null) {
      return const [];
    }
    final card = p.hand.where((c) => c.id == cardId).firstOrNull;
    if (card == null || !playable(p).contains(card)) return const [];

    p.hand.remove(card);
    discardPile.add(card);
    drawnThisTurn = null;
    final events = <UnoEvent>[UnoEvent('${p.name}: ${card.label}')];

    // UNO jarimasi: bitta karta qoldi, lekin "UNO!" aytilmagan
    if (p.hand.length == 1) {
      if (p.saidUno) {
        events.add(UnoEvent('📢 ${p.name}: UNO!'));
      } else {
        give(p, 2);
        events.add(UnoEvent('🚨 ${p.name} "UNO!" demadi — jarima: +2 karta'));
      }
    }
    p.saidUno = false;

    if (p.hand.isEmpty) {
      winner = p;
      status = UnoStatus.finished;
      currentColor = card.isWild ? (color ?? UnoColor.red) : card.color;
      return events;
    }

    if (card.isWild) {
      if (color == null || color == UnoColor.wild) {
        pendingWild = card; // rang tanlanishini kutamiz
        return events;
      }
      events.addAll(_afterWild(card, color));
      return events;
    }

    currentColor = card.color;
    events.addAll(_applyAction(card));
    return events;
  }

  /// Wild tashlagandan keyin rang tanlash.
  List<UnoEvent> chooseColor(int playerId, UnoColor color) {
    final card = pendingWild;
    if (card == null || current.id != playerId || color == UnoColor.wild) return const [];
    pendingWild = null;
    return _afterWild(card, color);
  }

  List<UnoEvent> _afterWild(UnoCard card, UnoColor color) {
    currentColor = color;
    final events = [UnoEvent('🎨 Rang: ${UnoCard.colorEmoji(color)} ${UnoCard.colorName(color)}')];
    if (card.kind == UnoKind.wild4) {
      final victim = players[_next()];
      give(victim, 4);
      events.add(UnoEvent('➕ ${victim.name} 4 ta karta oldi va navbatini o\'tkazdi'));
      _advance(2);
    } else {
      _advance();
    }
    return events;
  }

  List<UnoEvent> _applyAction(UnoCard card) {
    switch (card.kind) {
      case UnoKind.skip:
        final skipped = players[_next()];
        _advance(2);
        return [UnoEvent('⊘ ${skipped.name} navbatini o\'tkazdi')];
      case UnoKind.reverse:
        if (players.length == 2) {
          _advance(2); // ikki kishida — Skip kabi
          return const [UnoEvent('⇄ Yo\'nalish o\'zgardi — yana o\'sha o\'yinchi')];
        }
        direction = -direction;
        _advance();
        return const [UnoEvent('⇄ Yo\'nalish o\'zgardi')];
      case UnoKind.draw2:
        final victim = players[_next()];
        give(victim, 2);
        _advance(2);
        return [UnoEvent('➕ ${victim.name} 2 ta karta oldi va navbatini o\'tkazdi')];
      default:
        _advance();
        return const [];
    }
  }

  /// Karta olish: navbatda bir marta. Olingan kartani tashlash yoki o'tkazish mumkin.
  UnoCard? draw(int playerId) {
    final p = player(playerId);
    if (p == null || p != current || status != UnoStatus.playing) return null;
    if (drawnThisTurn != null || pendingWild != null) return null;
    final got = give(p, 1);
    if (got.isEmpty) return null;
    drawnThisTurn = got.single;
    return got.single;
  }

  /// Karta olgandan keyin navbatni o'tkazish.
  bool pass(int playerId) {
    final p = player(playerId);
    if (p == null || p != current || drawnThisTurn == null) return false;
    _advance();
    return true;
  }

  /// Vaqt tugadi: o'yinchi karta oladi (agar olmagan bo'lsa) va navbat o'tadi.
  /// Wild rangi tanlanmagan bo'lsa — tasodifiy rang.
  List<UnoEvent> timeout() {
    if (status != UnoStatus.playing) return const [];
    final p = current;
    p.timeouts++;
    if (pendingWild != null) {
      final colors = [UnoColor.red, UnoColor.yellow, UnoColor.green, UnoColor.blue];
      return [UnoEvent('⏰ ${p.name} rang tanlamadi'), ...chooseColor(p.id, colors[_r.nextInt(4)])];
    }
    if (drawnThisTurn == null) give(p, 1);
    _advance();
    return [UnoEvent('⏰ ${p.name} vaqtida yurmadi — 1 karta oldi')];
  }
}
