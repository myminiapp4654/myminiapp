import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/server_client.dart';
import '../telegram/telegram.dart';
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
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<String?>(
                valueListenable: _server.authError,
                builder: (context, error, _) {
                  if (error != null) return _buildError(error);
                  if (Telegram.isAvailable || _devStarted) {
                    return _buildConnecting();
                  }
                  return _buildDevForm();
                },
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
          return const CircularProgressIndicator();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Serverga ulanib bo'lmadi, qayta urinilmoqda..."),
            const SizedBox(height: 8),
            Text(_server.serverUrl,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _server.retryNow,
              child: const Text('Hozir qayta urinish'),
            ),
            if (!Telegram.isAvailable)
              TextButton(
                onPressed: () => setState(() => _devStarted = false),
                child: const Text('Orqaga'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildError(String error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(error, textAlign: TextAlign.center),
        if (!Telegram.isAvailable) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _server.authError.value = null;
              setState(() => _devStarted = false);
            },
            child: const Text('Orqaga'),
          ),
        ],
      ],
    );
  }

  Widget _buildDevForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Test rejimi'),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Ismingiz',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _devLogin(),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _devLogin, child: const Text('Kirish')),
      ],
    );
  }
}
