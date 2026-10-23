import 'dart:math';

import 'stack_game.dart';

/// Stack'da kompyuter o'yinchi: odamga o'xshab, bir oz kechikib va xato bilan bosadi.
///
/// Har qavat uchun "mo'ljal" tanlanadi — blokni pastdagisidan qancha siljitib
/// qo'yishi. Daraja qancha yuqori bo'lsa, xato shuncha kichik va aniq qo'yish
/// ehtimoli shuncha katta. Tezlik oshgan sari xato ham oshadi, shuning uchun
/// kompyuter ham oxir-oqibat yiqiladi.
class StackBot {
  final int level; // 1 — oson, 2 — o'rta, 3 — qiyin
  final Random _r;

  double? _aim;
  double _wait = 0;

  StackBot(this.level, [Random? random]) : _r = random ?? Random();

  double get _sigma => switch (level) { 1 => 1.5, 2 => 0.95, _ => 0.55 };
  double get _growth => switch (level) { 1 => 0.07, 2 => 0.045, _ => 0.03 };
  double get _perfect => switch (level) { 1 => 0.12, 2 => 0.28, _ => 0.45 };

  double _pickAim(StackGame g) {
    // Aniq qo'yish ehtimoli ham qavat sari kamayadi
    final perfect = _perfect * max(0.3, 1 - g.score / 60);
    if (_r.nextDouble() < perfect) return (_r.nextDouble() - 0.5) * 0.4;
    // Normal taqsimotga yaqin xato
    final n = (_r.nextDouble() + _r.nextDouble() + _r.nextDouble() - 1.5) * 1.4;
    return n * (_sigma + g.score * _growth);
  }

  /// Har kadrda [StackGame.update] dan keyin chaqiriladi. true — hozir bosish kerak.
  bool update(StackGame g, double dt) {
    if (g.over) return false;
    if (_aim == null) {
      _aim = _pickAim(g);
      // Odamdek: yangi blok chiqqach biroz kutadi
      _wait = 0.3 + _r.nextDouble() * 0.6;
    }
    _wait -= dt;
    if (_wait > 0) return false;
    // Blok mo'ljal yonidan o'tayotgan bo'lsa — bosamiz
    if ((g.offset - _aim!).abs() <= g.speed * dt * 0.6 + 0.05) {
      _aim = null;
      return true;
    }
    return false;
  }
}
