import 'dart:async';
import 'package:flutter/material.dart';
import '../net/server_client.dart';
import '../services/quiz_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';

class QuizScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const QuizScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _service = QuizService();
  Timer? _timer;

  int _displayedQuestion = -1;
  int _timeLeft = 15;
  int? _myAnswer;
  bool _revealed = false;
  String _prevStatus = '';

  static const _questionDuration = 15;

  static const _optionColors = [kBlue, Color(0xFF8800CC), kAccentDim, kDanger];
  static const _optionLabels = ['A', 'B', 'C', 'D'];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int total, List questions) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        setState(() => _revealed = true);
        if (widget.isHost) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _service.nextQuestion(widget.roomCode, _displayedQuestion);
            }
          });
        }
      }
    });
  }

  void _onNewQuestion(int qIndex, int total, List questions) {
    if (qIndex == _displayedQuestion) return;
    _timer?.cancel();
    setState(() {
      _displayedQuestion = qIndex;
      _timeLeft = _questionDuration;
      _myAnswer = null;
      _revealed = false;
    });
    if (qIndex < total) _startTimer(total, questions);
  }

  Future<void> _submitAnswer(int index, int correct) async {
    if (_myAnswer != null || _revealed) return;
    final isCorrect = index == correct;
    setState(() => _myAnswer = index);
    AudioService.instance.playSfx(isCorrect ? 'correct' : 'wrong');
    await _service.submitAnswer(widget.roomCode, index);
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
        final questions = List<Map<String, dynamic>>.from(data['questions']);
        final currentQ = data['currentQuestion'] as int;
        final players = data['players'] as Map<String, dynamic>;

        if (status == 'finished' && _prevStatus != 'finished') {
          _prevStatus = status;
          AudioService.instance.playSfx('win');
        } else if (status != _prevStatus) {
          _prevStatus = status;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && status == 'playing') {
            _onNewQuestion(currentQ, questions.length, questions);
          }
        });

        if (status == 'waiting') return _buildWaiting(players);
        if (status == 'finished') return _buildLeaderboard(players);

        if (currentQ < 0 || currentQ >= questions.length) return pixelLoading();

        final q = questions[currentQ];
        final options = List<String>.from(q['o']);
        final correct = q['c'] as int;

        return Scaffold(
          backgroundColor: kBg,
          appBar: pixelAppBar(
            title: 'QUIZ',
            subtitle: 'SAVOL ${currentQ + 1}/${questions.length}',
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Players row
                  Row(
                    children: [
                      ...players.entries.take(4).map((e) {
                        final p = e.value as Map;
                        final name = p['name'] as String;
                        return Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 4),
                          color: kWarn.withValues(alpha: 0.2),
                          child: Center(
                            child: pixelText(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              kWarn, 12,
                            ),
                          ),
                        );
                      }),
                      const Spacer(),
                      pixelText('VAQT: $_timeLeft', _timerColor(), 13),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Timer bar
                  Stack(
                    children: [
                      Container(height: 8, color: kBorder),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        height: 8,
                        width: (MediaQuery.of(context).size.width - 32) *
                            (_timeLeft / _questionDuration),
                        color: _timerColor(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Question
                  Expanded(
                    flex: 2,
                    child: pixelContainer(
                      borderColor: kWarn.withValues(alpha: 0.6),
                      color: kWarn.withValues(alpha: 0.05),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            pixelText('?', kWarn, 28),
                            const SizedBox(height: 12),
                            Text(
                              q['q'] as String,
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Options
                  Expanded(
                    flex: 3,
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(options.length, (i) {
                        return _buildOption(i, options[i], correct);
                      }),
                    ),
                  ),

                  if (_revealed && _myAnswer != null) ...[
                    const SizedBox(height: 8),
                    pixelContainer(
                      borderColor: _myAnswer == correct ? kAccent : kDanger,
                      color: (_myAnswer == correct ? kAccent : kDanger)
                          .withValues(alpha: 0.1),
                      child: pixelText(
                        _myAnswer == correct
                            ? "TO'G'RI! +${_timeLeft * 100} BALL"
                            : "NOTO'G'RI! TO'G'RI: ${options[correct]}",
                        _myAnswer == correct ? kAccent : kDanger,
                        12,
                      ),
                    ),
                  ],

                  if (_revealed && _myAnswer == null) ...[
                    const SizedBox(height: 8),
                    pixelContainer(
                      borderColor: kDanger,
                      color: kDanger.withValues(alpha: 0.1),
                      child: pixelText(
                        "VAQT TUGADI! TO'G'RI: ${options[correct]}",
                        kDanger, 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _timerColor() =>
      _timeLeft > 8 ? kAccent : _timeLeft > 4 ? kWarn : kDanger;

  Widget _buildOption(int index, String text, int correct) {
    Color borderColor = _optionColors[index];
    Color bgColor = _optionColors[index].withValues(alpha: 0.1);

    if (_revealed || _myAnswer != null) {
      if (index == correct) {
        borderColor = kAccent;
        bgColor = kAccent.withValues(alpha: 0.15);
      } else if (_myAnswer == index) {
        borderColor = kDanger;
        bgColor = kDanger.withValues(alpha: 0.15);
      } else {
        borderColor = kBorder;
        bgColor = kPanel;
      }
    }

    final canTap = !_revealed && _myAnswer == null;

    return GestureDetector(
      onTap: canTap ? () => _submitAnswer(index, correct) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: canTap
              ? [BoxShadow(
                  color: _optionColors[index].withValues(alpha: 0.3),
                  blurRadius: 0,
                  offset: const Offset(2, 2))]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              color: borderColor.withValues(alpha: 0.2),
              child: Center(
                child: pixelText(_optionLabels[index], borderColor, 11),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    color: kWhite,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_revealed && index == correct)
              const Icon(Icons.check, color: kAccent, size: 16),
            if (_revealed && _myAnswer == index && index != correct)
              const Icon(Icons.close, color: kDanger, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(Map<String, dynamic> players) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: pixelAppBar(title: 'QUIZ'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              pixelText('[ QUIZ ]', kWarn, 24),
              const SizedBox(height: 16),
              pixelText(
                widget.isHost
                    ? "HAMMA TAYYOR BO'LGANDA BOSHLANG"
                    : 'QUIZ BOSHLANISHINI KUTING...',
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
                        color: kWarn.withValues(alpha: 0.2),
                        child: Center(
                          child: pixelText(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            kWarn, 12,
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
                  onTap: () => _service.startQuiz(widget.roomCode),
                  color: kWarn,
                  textColor: kBg,
                  borderColor: kWarn,
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

  Widget _buildLeaderboard(Map<String, dynamic> players) {
    final sorted = players.entries.toList()
      ..sort((a, b) => ((b.value as Map)['score'] as int)
          .compareTo((a.value as Map)['score'] as int));
    final medals = ['1', '2', '3'];

    return Scaffold(
      backgroundColor: kBg,
      appBar: pixelAppBar(title: 'QUIZ  NATIJALAR'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              pixelText('[ O\'YIN TUGADI ]', kAccent, 22),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final entry = sorted[i];
                    final p = entry.value as Map;
                    final isMe = entry.key == _service.myUid;
                    final score = p['score'] as int;
                    final color = i == 0 ? kWarn : i == 1 ? kDim : kBorder;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMe ? kWarn.withValues(alpha: 0.1) : kPanel,
                        border: Border.all(
                          color: isMe ? kWarn : color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.zero,
                        boxShadow: isMe
                            ? [BoxShadow(color: kWarn.withValues(alpha: 0.3), blurRadius: 0, offset: const Offset(3, 3))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          pixelText(
                            i < 3 ? medals[i] : '${i + 1}',
                            color, 18,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: pixelText(
                              isMe
                                  ? '${(p['name'] as String).toUpperCase()} *'
                                  : (p['name'] as String).toUpperCase(),
                              isMe ? kWarn : kWhite,
                              13,
                              align: TextAlign.left,
                            ),
                          ),
                          pixelText('$score BALL', kWarn, 14),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
