import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../net/server_client.dart';
import '../services/scrambled_word_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';

class _LetterDrag {
  final int index;
  final String letter;
  const _LetterDrag({required this.index, required this.letter});
}

class ScrambledWordScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const ScrambledWordScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<ScrambledWordScreen> createState() => _ScrambledWordScreenState();
}

class _ScrambledWordScreenState extends State<ScrambledWordScreen>
    with TickerProviderStateMixin {
  final _service = ScrambledWordService();

  late AnimationController _winCtrl;
  late Animation<double> _winAnim;
  int? _wrongSlotIndex;
  String _prevStatus = '';

  static const _tileColors = [
    Color(0xFF0066CC),
    Color(0xFF8800CC),
    Color(0xFFCC4400),
    Color(0xFF006644),
    Color(0xFFCC0066),
    Color(0xFF004488),
    Color(0xFF884400),
    Color(0xFF006600),
    Color(0xFF550088),
    Color(0xFF880044),
  ];

  @override
  void initState() {
    super.initState();
    _winCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _winAnim = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _winCtrl.dispose();
    super.dispose();
  }

  Color _colorFor(String letter) =>
      _tileColors[letter.codeUnitAt(0) % _tileColors.length];

  Map<String, int> _calcAvail(String word, List<String> slots) {
    final avail = <String, int>{};
    for (var c in word.split('')) {
      avail[c] = (avail[c] ?? 0) + 1;
    }
    for (var s in slots) {
      if (s.isNotEmpty) avail[s] = (avail[s] ?? 1) - 1;
    }
    return avail;
  }

  List<bool> _buildTileAvailability(
      List<String> letters, Map<String, int> avail) {
    final result = <bool>[];
    final rem = Map<String, int>.from(avail);
    for (var letter in letters) {
      final count = rem[letter] ?? 0;
      result.add(count > 0);
      if (count > 0) rem[letter] = count - 1;
    }
    return result;
  }

  Future<void> _onDrop(
      String letter, int slotIdx, List<String> slots, String word) async {
    if (slots[slotIdx].isNotEmpty) return;
    if (word[slotIdx] == letter) {
      await _service.placeLetter(widget.roomCode, slotIdx, letter);
      AudioService.instance.playSfx('score');
    } else {
      setState(() => _wrongSlotIndex = slotIdx);
      AudioService.instance.playSfx('wrong');
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongSlotIndex = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return pixelLoading();

        if (!snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: kBg,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pixelText("[ XONA O'CHIRILDI ]", kDanger, 18),
                  const SizedBox(height: 20),
                  pixelButton(
                    label: '◄ ORQAGA',
                    onTap: () => Navigator.pop(context),
                    color: kBg,
                    textColor: kAccent,
                    borderColor: kAccent,
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final word = data['word'] as String;
        final hint = data['hint'] as String;
        final letters = List<String>.from(data['letters']);
        final slots = List<String>.from(data['slots']);
        final status = data['status'] as String;
        final player1 = data['player1'] as Map<String, dynamic>;
        final player2 = data['player2'] as Map<String, dynamic>?;

        if (status == 'finished' && _prevStatus != 'finished') {
          _prevStatus = status;
          _winCtrl.forward(from: 0);
          AudioService.instance.playSfx('win');
        } else if (status != _prevStatus) {
          _prevStatus = status;
        }

        final avail = _calcAvail(word, slots);
        final tileAvail = _buildTileAvailability(letters, avail);
        final filled = slots.where((s) => s.isNotEmpty).length;

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kPanel,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kAccent),
              onPressed: () async {
                if (status != 'finished' && widget.isHost) {
                  await _service.deleteRoom(widget.roomCode);
                }
                if (mounted) Navigator.pop(this.context);
              },
            ),
            title: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod nusxalandi!')));
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pixelText('HARFLARNI TOP  ', kAccent, 13),
                  pixelText(widget.roomCode, kWarn, 12),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, color: kDim, size: 12),
                ],
              ),
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildPlayers(player1, player2),
                const SizedBox(height: 12),
                _buildHint(hint),
                const SizedBox(height: 14),
                if (status == 'waiting')
                  Expanded(child: _buildWaiting())
                else if (status == 'finished')
                  Expanded(child: _buildFinished(word))
                else ...[
                  _buildSlots(word, slots),
                  const SizedBox(height: 10),
                  _buildProgress(filled, word.length),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildLetterArea(letters, tileAvail, slots, word),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayers(Map<String, dynamic> player1, Map<String, dynamic>? player2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _playerChip(
            player1['name'] as String? ?? '?', kAccent,
            player1['uid'] == _service.myUid,
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: pixelText('VS', kDim, 12),
          ),
          Expanded(child: _playerChip(
            player2?['name'] as String? ?? '...',
            kWarn, player2?['uid'] == _service.myUid,
          )),
        ],
      ),
    );
  }

  Widget _playerChip(String name, Color color, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20, height: 20,
            color: color.withValues(alpha: 0.2),
            child: Center(
              child: pixelText(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                color, 10,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: pixelText(
              isMe ? '${name.toUpperCase()} *' : name.toUpperCase(),
              color, 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: pixelContainer(
        borderColor: kWarn.withValues(alpha: 0.5),
        color: kWarn.withValues(alpha: 0.06),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            pixelText('?', kWarn, 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hint,
                style: const TextStyle(
                    color: kWarn,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlots(String word, List<String> slots) {
    return LayoutBuilder(builder: (context, constraints) {
      final total = word.length;
      final spacing = 4.0;
      final available = constraints.maxWidth - 32 - spacing * (total - 1);
      final slotW = (available / total).clamp(30.0, 52.0);
      final fontSize = (slotW * 0.4).clamp(13.0, 20.0);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final isFilled = slots[i].isNotEmpty;
            final isWrong = _wrongSlotIndex == i;
            final color = isFilled ? _colorFor(slots[i]) : null;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: DragTarget<_LetterDrag>(
                builder: (ctx, candidates, _) {
                  final hovered = candidates.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: slotW,
                    height: slotW * 1.2,
                    decoration: BoxDecoration(
                      color: isWrong
                          ? kDanger.withValues(alpha: 0.2)
                          : isFilled
                              ? color!.withValues(alpha: 0.15)
                              : hovered
                                  ? kAccent.withValues(alpha: 0.1)
                                  : kPanel,
                      border: Border.all(
                        color: isWrong
                            ? kDanger
                            : isFilled
                                ? color!
                                : hovered
                                    ? kAccent
                                    : kBorder,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.zero,
                      boxShadow: isFilled
                          ? [BoxShadow(
                              color: color!.withValues(alpha: 0.4),
                              blurRadius: 0,
                              offset: const Offset(2, 2))]
                          : null,
                    ),
                    child: Center(
                      child: isFilled
                          ? Text(slots[i],
                              style: TextStyle(
                                color: color,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ))
                          : Text('${i + 1}',
                              style: TextStyle(
                                color: kBorder,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              )),
                    ),
                  );
                },
                onWillAcceptWithDetails: (d) => slots[i].isEmpty,
                onAcceptWithDetails: (d) =>
                    _onDrop(d.data.letter, i, slots, word),
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _buildProgress(int filled, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              pixelText('$filled / $total HARF', kDim, 10,
                  align: TextAlign.left),
              pixelText('${((filled / total) * 100).round()}%', kDim, 10),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(height: 6, color: kBorder),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                width: (MediaQuery.of(context).size.width - 32) *
                    (filled / total),
                color: filled == total ? kAccent : kBlue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLetterArea(List<String> letters, List<bool> avail,
      List<String> slots, String word) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: pixelContainer(
        borderColor: kBorder,
        color: kPanel,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(letters.length, (i) {
              final letter = letters[i];
              final isAvail = avail[i];
              final color = _colorFor(letter);

              if (!isAvail) {
                return Container(
                  width: 50,
                  height: 54,
                  decoration: BoxDecoration(
                    color: kBg,
                    border: Border.all(color: kBg, width: 2),
                    borderRadius: BorderRadius.zero,
                  ),
                );
              }

              return Draggable<_LetterDrag>(
                data: _LetterDrag(index: i, letter: letter),
                feedback: Material(
                  color: Colors.transparent,
                  child: _tile(letter, color, scale: 1.1, shadow: true),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.2,
                  child: _tile(letter, color),
                ),
                child: _tile(letter, color),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _tile(String letter, Color color,
      {double scale = 1.0, bool shadow = false}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 50,
        height: 54,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: shadow ? 0.6 : 0.3),
              blurRadius: 0,
              offset: Offset(shadow ? 3.0 : 2.0, shadow ? 3.0 : 2.0),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(
              color: kWhite,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            pixelText('[ KUTILMOQDA ]', kAccent, 20),
            const SizedBox(height: 16),
            pixelText("IKKINCHI O'YINCHI KUTING...", kDim, 11),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod nusxalandi!')));
              },
              child: pixelContainer(
                borderColor: kAccent,
                color: kAccentDim.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy, color: kAccent, size: 16),
                    const SizedBox(width: 10),
                    pixelText(widget.roomCode, kAccent, 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinished(String word) {
    return ScaleTransition(
      scale: _winAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              pixelText('[ TOPDINGLАР! ]', kAccent, 26),
              const SizedBox(height: 8),
              pixelText('IKKOVINGIZ BIRGALIKDA!', kDim, 12),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: word.split('').map((c) {
                    final color = _colorFor(c);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 40,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(color: color, width: 2),
                          borderRadius: BorderRadius.zero,
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 0,
                                offset: const Offset(2, 2)),
                          ],
                        ),
                        child: Center(
                          child: pixelText(c, kWhite, 18),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  if (widget.isHost) ...[
                    Expanded(
                      child: pixelButton(
                        label: '↻ YANGI SO\'Z',
                        onTap: () => _service.playAgain(widget.roomCode),
                        color: kBlue,
                        textColor: kWhite,
                        borderColor: kBlue,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: pixelButton(
                      label: '◄ CHIQISH',
                      onTap: () => Navigator.pop(context),
                      color: kBg,
                      textColor: kAccent,
                      borderColor: kAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
