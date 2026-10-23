import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/checkers_service.dart';
import 'checkers_screen.dart';

class CheckersLobbyScreen extends StatefulWidget {
  const CheckersLobbyScreen({super.key});

  @override
  State<CheckersLobbyScreen> createState() => _CheckersLobbyScreenState();
}

class _CheckersLobbyScreenState extends State<CheckersLobbyScreen> {
  final _service = CheckersService();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    try {
      final code = await _service.createRoom();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CheckersScreen(roomCode: code, isCreator: true),
          ),
        );
      }
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
            const SnackBar(
                content: Text('Xona topilmadi yoki to\'lgan')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CheckersScreen(roomCode: code, isCreator: false),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Shashka', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Board preview icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(16, (i) {
                    final row = i ~/ 4, col = i % 4;
                    final isDark = (row + col) % 2 == 1;
                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF8B4513)
                            : const Color(0xFFEECFA0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: isDark && row < 2
                          ? const Center(
                              child: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Color(0xFF222222)))
                          : isDark && row >= 2
                              ? const Center(
                                  child: CircleAvatar(
                                      radius: 6,
                                      backgroundColor: Colors.white))
                              : null,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Shashka',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              const Text('2 o\'yinchi • Online',
                  style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createRoom,
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white),
                  label: const Text('Yangi xona yaratish',
                      style:
                          TextStyle(fontSize: 17, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Row(children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child:
                      Text('yoki', style: TextStyle(color: Colors.white38)),
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
                  hintStyle: const TextStyle(
                      color: Colors.white24, letterSpacing: 4),
                  counterText: '',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF8B4513)),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _joinRoom,
                  icon: const Icon(Icons.login, color: Color(0xFF8B4513)),
                  label: const Text('Xonaga kirish',
                      style: TextStyle(
                          fontSize: 17, color: Color(0xFF8B4513))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B4513)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: Color(0xFF8B4513)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
