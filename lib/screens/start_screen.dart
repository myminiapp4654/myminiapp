import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/server_client.dart';
import '../telegram/telegram.dart';
import '../ui/kit.dart';
import 'home_screen.dart';

/// Ilova ochilganda: serverga ulanadi va foydalanuvchini kiritadi.
///  - Telegram ichida: avtomatik
///  - Oddiy brauzerda: test uchun ism so'raladi (server DEV_LOGIN=true bo'lsa)
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _server = ServerClient.instance;
  final _nameController = TextEditingController();
  bool _devStarted = false;

  @override
  void initState() {
    super.initState();
    if (Telegram.isAvailable) _server.autoStart();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _devLogin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    var id = 'tmp${DateTime.now().millisecondsSinceEpoch}';
    try {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('dev_id') ??
          List.generate(12, (_) => Random.secure().nextInt(36).toRadixString(36))
              .join();
      await prefs.setString('dev_id', id);
    } catch (_) {}
    setState(() => _devStarted = true);
    _server.startWithDevLogin(name, id);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: _server.user,
      builder: (context, user, _) {
        if (user != null) return const HomeScreen();
        return Scaffold(
          backgroundColor: GamePalette.home.bottom,
          body: GameBackground(
            palette: GamePalette.home,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: const GlowText('BREAK TIME', size: 40, color: Color(0xFFB9AEFF)),
                      ),
                      const SizedBox(height: 6),
                      const Text("Do'stlar bilan o'yinlar",
                          style: TextStyle(color: Colors.white60, fontSize: 15)),
                      const SizedBox(height: 40),
                      ValueListenableBuilder<String?>(
                        valueListenable: _server.authError,
                        builder: (context, error, _) {
                          if (error != null) return _buildError(error);
                          if (Telegram.isAvailable || _devStarted) {
                            return _buildConnecting();
                          }
                          return _buildDevForm();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Ulanmoqda; ulanib bo'lmasa — sababi va manzil.
  Widget _buildConnecting() {
    return ValueListenableBuilder<ConnState>(
      valueListenable: _server.state,
      builder: (context, state, _) {
        if (state != ConnState.offline) {
          return const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFB9AEFF)),
          );
        }
        return Glass(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF8A80), size: 36),
              const SizedBox(height: 8),
              const Text("Serverga ulanib bo'lmadi, qayta urinilmoqda...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(_server.serverUrl,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              GameButton(
                label: 'Hozir qayta urinish',
                icon: Icons.refresh_rounded,
                colors: const [Color(0xFF8C7BFF), Color(0xFF5B3FD9)],
                onPressed: _server.retryNow,
              ),
              if (!Telegram.isAvailable)
                TextButton(
                  onPressed: () => setState(() => _devStarted = false),
                  child: const Text('Orqaga', style: TextStyle(color: Colors.white70)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Glass(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFFD54F), size: 36),
          const SizedBox(height: 8),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          if (!Telegram.isAvailable) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _server.authError.value = null;
                setState(() => _devStarted = false);
              },
              child: const Text('Orqaga', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevForm() {
    return Glass(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Test rejimi',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            maxLength: 30,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ismingiz',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onSubmitted: (_) => _devLogin(),
          ),
          const SizedBox(height: 8),
          GameButton(
            label: 'Kirish',
            icon: Icons.login_rounded,
            colors: const [Color(0xFF8C7BFF), Color(0xFF5B3FD9)],
            onPressed: _devLogin,
          ),
        ],
      ),
    );
  }
}
