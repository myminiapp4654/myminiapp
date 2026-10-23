import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/server_client.dart';
import '../telegram/telegram.dart';
import '../theme/pixel_ui.dart';
import 'home_screen.dart';

/// Ilova ochilganda: serverga ulanadi va foydalanuvchini kiritadi.
///  - Telegram ichida: avtomatik (initData orqali)
///  - Oddiy brauzerda: faqat test uchun ism so'raladi (server DEV_LOGIN=true bo'lsa)
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  final _server = ServerClient.instance;
  final _nameController = TextEditingController();
  late final AnimationController _pulse;
  bool _devStarted = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    if (Telegram.isAvailable) {
      _server.autoStart();
    } else {
      _loadDevName();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadDevName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _nameController.text = prefs.getString('dev_name') ?? '';
    } catch (_) {}
  }

  Future<void> _devLogin() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    String id;
    try {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('dev_id') ?? '';
      if (id.isEmpty) {
        id = List.generate(12, (_) => Random.secure().nextInt(36).toRadixString(36))
            .join();
        await prefs.setString('dev_id', id);
      }
      await prefs.setString('dev_name', name);
    } catch (_) {
      id = 'tmp${DateTime.now().millisecondsSinceEpoch}';
    }
    setState(() => _devStarted = true);
    _server.startWithDevLogin(name, id);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: _server.user,
      builder: (context, user, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: user != null
              ? const HomeScreen(key: ValueKey('home'))
              : _buildGate(),
        );
      },
    );
  }

  Widget _buildGate() {
    return Scaffold(
      key: const ValueKey('gate'),
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ValueListenableBuilder<String?>(
              valueListenable: _server.authError,
              builder: (context, error, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: Tween(begin: 0.5, end: 1.0).animate(_pulse),
                      child: pixelText('[ OYINIM ]', kAccent, 32),
                    ),
                    const SizedBox(height: 8),
                    pixelText("DO'STLAR BILAN O'YINLAR", kDim, 12),
                    const SizedBox(height: 40),
                    if (error != null)
                      _buildError(error)
                    else if (Telegram.isAvailable || _devStarted)
                      _buildConnecting()
                    else
                      _buildDevForm(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnecting() {
    return ValueListenableBuilder<ConnState>(
      valueListenable: _server.state,
      builder: (context, state, _) {
        final slow = state == ConnState.offline;
        return Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: kAccent, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            pixelText(slow ? 'SERVER UYG\'ONMOQDA...' : 'ULANMOQDA...', kDim, 11),
            if (slow) ...[
              const SizedBox(height: 8),
              pixelText('BIRINCHI OCHILISH 1 DAQIQAGACHA CHO\'ZILISHI MUMKIN',
                  kDim, 9),
            ],
          ],
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Column(
      children: [
        pixelContainer(
          borderColor: kDanger,
          color: kDanger.withValues(alpha: 0.1),
          padding: const EdgeInsets.all(16),
          child: pixelText(error.toUpperCase(), kDanger, 12),
        ),
        const SizedBox(height: 16),
        if (!Telegram.isAvailable)
          pixelButton(
            label: '◄ ORQAGA',
            onTap: () {
              _server.authError.value = null;
              setState(() => _devStarted = false);
            },
            color: kBg,
            textColor: kDim,
            borderColor: kBorder,
          ),
      ],
    );
  }

  Widget _buildDevForm() {
    return pixelContainer(
      borderColor: kBorder,
      color: kPanel,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          pixelText('TEST REJIMI', kWarn, 13),
          const SizedBox(height: 6),
          pixelText("Telegram'siz faqat sinab ko'rish uchun", kDim, 10),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            maxLength: 30,
            style: const TextStyle(
                color: kWhite,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold),
            decoration: pixelInputDecoration('ISMINGIZ', icon: Icons.person),
            onSubmitted: (_) => _devLogin(),
          ),
          const SizedBox(height: 12),
          pixelButton(
            label: '> KIRISH',
            onTap: _devLogin,
            color: kAccent,
            textColor: kBg,
            borderColor: kAccent,
          ),
        ],
      ),
    );
  }
}
