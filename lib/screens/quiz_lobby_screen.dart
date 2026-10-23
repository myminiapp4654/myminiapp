import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/quiz_service.dart';
import 'quiz_screen.dart';

class QuizLobbyScreen extends StatefulWidget {
  const QuizLobbyScreen({super.key});

  @override
  State<QuizLobbyScreen> createState() => _QuizLobbyScreenState();
}

class _QuizLobbyScreenState extends State<QuizLobbyScreen> {
  final _service = QuizService();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _questionCount = 10;
  String? _createdCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    try {
      final code = await _service.createRoom(_questionCount);
      setState(() => _createdCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6 belgili kod kiriting')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final joined = await _service.joinRoom(code);
      if (!joined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xona topilmadi yoki boshlangan')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizScreen(roomCode: code, isHost: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Quiz', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _createdCode != null
              ? _buildWaitingRoom()
              : _buildSetupRoom(),
        ),
      ),
    );
  }

  Widget _buildSetupRoom() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🧠', style: TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Quiz',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const Text('Kulgili savol-javob',
            style: TextStyle(color: Colors.white38)),
        const SizedBox(height: 40),

        // Savol soni
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Savol soni:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15, 20].map((n) {
                  final selected = _questionCount == n;
                  return GestureDetector(
                    onTap: () => setState(() => _questionCount = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.amber
                            : const Color(0xFF0F3460),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('$n',
                            style: TextStyle(
                                color: selected
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _createRoom,
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            label: const Text('Xona yaratish',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Row(children: [
          Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('yoki', style: TextStyle(color: Colors.white38)),
          ),
          Expanded(child: Divider(color: Colors.white24)),
        ]),
        const SizedBox(height: 24),

        TextField(
          controller: _codeController,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 4,
              fontWeight: FontWeight.bold),
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'XONA KODI',
            hintStyle:
                const TextStyle(color: Colors.white24, letterSpacing: 4),
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.amber),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _joinRoom,
            icon: const Icon(Icons.login, color: Colors.amber),
            label: const Text('Xonaga kirish',
                style: TextStyle(fontSize: 16, color: Colors.amber)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: Colors.amber),
        ],
      ],
    );
  }

  Widget _buildWaitingRoom() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.gameStream(_createdCode!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.amber));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final players = data['players'] as Map<String, dynamic>;

        return Column(
          children: [
            const Text('🎮',
                style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text('Xona tayyor!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _createdCode!,
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white38),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: _createdCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kod nusxalandi!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$_questionCount ta savol',
                style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 24),

            // O'yinchilar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'O\'yinchilar (${players.length})',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...players.entries.map((e) {
                    final p = e.value as Map;
                    final isMe = e.key == _service.myUid;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Colors.amber.withValues(alpha: 0.2),
                            child: Text(
                              (p['name'] as String).isEmpty ? '?' : (p['name'] as String)[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isMe ? '${p['name']} (Sen)' : p['name'],
                            style:
                                const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          if (isMe)
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: players.length < 2
                    ? null
                    : () {
                        _service.startQuiz(_createdCode!);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              roomCode: _createdCode!,
                              isHost: true,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: Text(
                  players.length < 2
                      ? 'Kamida 2 o\'yinchi kerak...'
                      : 'Boshlash!',
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  disabledBackgroundColor:
                      Colors.amber.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
