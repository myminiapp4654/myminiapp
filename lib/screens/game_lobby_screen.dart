import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/game_service.dart';
import 'tictactoe_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final GameService _gameService = GameService();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _createdRoomCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    try {
      final code = await _gameService.createRoom();
      setState(() => _createdRoomCode = code);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicTacToeScreen(roomCode: code, isCreator: true),
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
      final joined = await _gameService.joinRoom(code);
      if (!joined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xona topilmadi yoki to\'lgan')),
          );
        }
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicTacToeScreen(roomCode: code, isCreator: false),
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
        title: const Text('X-O O\'yini',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.grid_3x3,
                  size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 12),
              const Text(
                'X - O',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 48),

              // Xona yaratish
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createRoom,
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white),
                  label: const Text('Yangi xona yaratish',
                      style: TextStyle(fontSize: 17, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
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

              // Xonaga ulashish
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
                        const BorderSide(color: Colors.deepPurpleAccent),
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
                  icon: const Icon(Icons.login, color: Colors.deepPurpleAccent),
                  label: const Text('Xonaga kirish',
                      style: TextStyle(
                          fontSize: 17, color: Colors.deepPurpleAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.deepPurpleAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                    color: Colors.deepPurpleAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
