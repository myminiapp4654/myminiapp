import 'package:flutter/material.dart';
import '../net/server_client.dart';
import '../services/ha_yoq_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';

class HaYoqScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const HaYoqScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<HaYoqScreen> createState() => _HaYoqScreenState();
}

class _HaYoqScreenState extends State<HaYoqScreen> {
  final _service = HaYoqService();
  final _questionController = TextEditingController();
  bool _submitting = false;
  String _prevStatus = '';

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Doc>(
      stream: _service.gameStream(widget.roomCode),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return pixelLoading();
        if (!snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return pixelLoading();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        if (status == 'finished' && _prevStatus != 'finished') {
          _prevStatus = status;
          AudioService.instance.playSfx('win');
        } else if (status != _prevStatus) {
          _prevStatus = status;
        }

        if (status == 'waiting') {
          final players = data['players'] as Map<String, dynamic>;
          return Scaffold(
            backgroundColor: kBg,
            appBar: pixelAppBar(title: "HA / YO'Q"),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    pixelText("[ HA / YO'Q ]", kAccent, 24),
                    const SizedBox(height: 16),
                    pixelText(
                      widget.isHost
                          ? "HAMMA TAYYOR BO'LGANDA BOSHLANG"
                          : "O'YIN BOSHLANISHINI KUTING...",
                      kDim, 11,
                    ),
                    const SizedBox(height: 20),
                    ...players.entries.map((e) {
                      final p = e.value as Map;
                      final name = p['name'] as String;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28, height: 28,
                              color: kAccent.withValues(alpha: 0.2),
                              child: Center(
                                child: pixelText(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  kAccent, 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            pixelText(name.toUpperCase(), kWhite, 13,
                                align: TextAlign.left),
                          ],
                        ),
                      );
                    }),
                    if (widget.isHost) ...[
                      const SizedBox(height: 24),
                      pixelButton(
                        label: '► BOSHLASH',
                        onTap: () => _service.startGame(widget.roomCode),
                        color: kAccent,
                        textColor: kBg,
                        borderColor: kAccent,
                        fontSize: 15,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        if (status == 'finished') return _buildResults(data);

        final order = List<String>.from(data['playerOrder']);
        final players = data['players'] as Map;
        final askerIdx = data['currentAskerIndex'] as int;
        final answererIdx = data['currentAnswererIndex'] as int;
        final askerUid = order[askerIdx];
        final answererUid = order[answererIdx];
        final askerName = players[askerUid]['name'] as String;
        final answererName = players[answererUid]['name'] as String;
        final qCount = data['questionCount'] as int;
        final askedCount = data['askedCount'] as int;
        final pendingQuestion = data['pendingQuestion'] as String?;
        final completedRounds = data['completedRounds'] as int;

        final amIAsker = _service.myUid == askerUid;
        final amIAnswerer = _service.myUid == answererUid;

        return Scaffold(
          backgroundColor: kBg,
          appBar: pixelAppBar(
            title: "HA / YO'Q",
            subtitle: 'TUR ${completedRounds + 1}/${order.length}',
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            pixelText(
                              '${askerName.toUpperCase()} → ${answererName.toUpperCase()}',
                              kWhite, 11, align: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                      pixelContainer(
                        borderColor: kAccent.withValues(alpha: 0.5),
                        color: kAccent.withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: pixelText(
                          'SAVOL ${askedCount + 1}/$qCount', kAccent, 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(height: 6, color: kBorder),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        width: (MediaQuery.of(context).size.width - 32) *
                            (askedCount / qCount),
                        color: kAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _buildContent(
                      amIAsker: amIAsker,
                      amIAnswerer: amIAnswerer,
                      askerName: askerName,
                      answererName: answererName,
                      pendingQuestion: pendingQuestion,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required bool amIAsker,
    required bool amIAnswerer,
    required String askerName,
    required String answererName,
    required String? pendingQuestion,
  }) {
    if (pendingQuestion == null) {
      if (amIAsker) return _buildAskerInput(answererName);
      if (amIAnswerer) {
        return _buildWaiting('$askerName SAVOL YOZYAPTI...',
            subtitle: 'TAYYORLANING!');
      }
      return _buildWaiting('$askerName → $answererName',
          subtitle: 'SAVOL KUTILMOQDA...');
    }

    if (amIAnswerer) return _buildAnswererView(pendingQuestion, askerName);
    if (amIAsker) {
      return _buildWaiting('$answererName JAVOB BERYAPTI...',
          question: pendingQuestion);
    }
    return _buildWaiting('JAVOB KUTILMOQDA', question: pendingQuestion);
  }

  Widget _buildAskerInput(String answererName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pixelText('[ SENING NAVBATING ]', kAccent, 16),
        const SizedBox(height: 8),
        pixelText('${answererName.toUpperCase()} GA SAVOL BERING!', kWhite, 13),
        const SizedBox(height: 6),
        pixelText("U FAQAT HA YOKI YO'Q DEB JAVOB BERADI", kDim, 10),
        const SizedBox(height: 24),
        TextField(
          controller: _questionController,
          style: const TextStyle(
              color: kWhite, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.done,
          decoration: pixelInputDecoration('SAVOLINGIZNI YOZING...'),
        ),
        const SizedBox(height: 16),
        pixelButton(
          label: _submitting ? 'YUBORILMOQDA...' : '► YUBORISH',
          onTap: _submitting
              ? null
              : () async {
                  final q = _questionController.text.trim();
                  if (q.isEmpty) return;
                  setState(() => _submitting = true);
                  await _service.askQuestion(widget.roomCode, q);
                  _questionController.clear();
                  if (mounted) setState(() => _submitting = false);
                },
          color: kAccent,
          textColor: kBg,
          borderColor: kAccent,
          fontSize: 14,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ],
    );
  }

  Widget _buildAnswererView(String question, String askerName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pixelText('[ SAVOL ]', kWarn, 18),
        const SizedBox(height: 8),
        pixelText('${askerName.toUpperCase()} SO\'RADI:', kDim, 11),
        const SizedBox(height: 14),
        pixelContainer(
          borderColor: kWarn.withValues(alpha: 0.6),
          color: kWarn.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(20),
          child: Text(
            question,
            style: const TextStyle(
                color: kWhite, fontSize: 18, fontWeight: FontWeight.w700,
                height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: _answerBtn('HA', kAccent, 'ha')),
            const SizedBox(width: 16),
            Expanded(child: _answerBtn("YO'Q", kDanger, 'yoq')),
          ],
        ),
      ],
    );
  }

  Widget _answerBtn(String label, Color color, String value) {
    return GestureDetector(
      onTap: _submitting
          ? null
          : () async {
              setState(() => _submitting = true);
              await _service.answerQuestion(widget.roomCode, value);
              if (mounted) setState(() => _submitting = false);
            },
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 0,
                offset: const Offset(3, 3)),
          ],
        ),
        child: Center(child: pixelText(label, color, 22)),
      ),
    );
  }

  Widget _buildWaiting(String title, {String subtitle = '', String? question}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pixelText('[ KUTILMOQDA ]', kDim, 16),
        const SizedBox(height: 16),
        pixelText(title, kWhite, 13),
        if (question != null) ...[
          const SizedBox(height: 16),
          pixelContainer(
            borderColor: kBorder,
            padding: const EdgeInsets.all(16),
            child: Text(question,
                style: const TextStyle(color: kWhite, fontSize: 16),
                textAlign: TextAlign.center),
          ),
        ],
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          pixelText(subtitle, kDim, 10),
        ],
      ],
    );
  }

  Widget _buildResults(Map<String, dynamic> data) {
    final log = List<Map<String, dynamic>>.from(
        (data['log'] as List).map((e) => Map<String, dynamic>.from(e)));
    final qCount = data['questionCount'] as int;

    final List<List<Map<String, dynamic>>> rounds = [];
    for (int i = 0; i < log.length; i += qCount) {
      final end = i + qCount > log.length ? log.length : i + qCount;
      rounds.add(log.sublist(i, end));
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: pixelAppBar(title: "HA / YO'Q  NATIJALAR"),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              pixelText("[ O'YIN TUGADI ]", kAccent, 20),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: rounds.length,
                  itemBuilder: (ctx, ri) {
                    final round = rounds[ri];
                    if (round.isEmpty) return const SizedBox();
                    final askerName = round[0]['askerName'] as String;
                    final answererName = round[0]['answererName'] as String;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: pixelContainer(
                            borderColor: kAccent.withValues(alpha: 0.4),
                            color: kAccent.withValues(alpha: 0.06),
                            child: pixelText(
                              '${askerName.toUpperCase()} → ${answererName.toUpperCase()}',
                              kAccent, 11,
                            ),
                          ),
                        ),
                        ...round.map((item) {
                          final isHa = item['answer'] == 'ha';
                          final color = isHa ? kAccent : kDanger;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: kPanel,
                              border: Border.all(
                                  color: color.withValues(alpha: 0.4), width: 1),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['question'] as String,
                                    style: const TextStyle(
                                        color: kWhite,
                                        fontSize: 13,
                                        fontFamily: 'monospace'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                pixelContainer(
                                  borderColor: color,
                                  color: color.withValues(alpha: 0.1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: pixelText(
                                      isHa ? 'HA' : "YO'Q", color, 11),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              pixelButton(
                label: '◄ XONAGA QAYTISH',
                onTap: () => Navigator.pop(context),
                color: kBg,
                textColor: kAccent,
                borderColor: kAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
