import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../net/server_client.dart';
import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Telegram havolasidagi xona kodi faqat bir marta ishlatiladi
  static bool _startParamUsed = false;

  final _server = ServerClient.instance;
  final _roomService = RoomService();
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _joinFromTelegramLink();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// t.me/bot?startapp=KOD orqali kelganda xonaga avtomatik kiradi.
  void _joinFromTelegramLink() {
    if (_startParamUsed) return;
    final code = Telegram.startParam?.trim().toUpperCase();
    if (code == null || code.length != 6) return;
    _startParamUsed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _codeController.text = code;
      _join();
    });
  }

  void _openRoom(String code, bool isHost) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RoomScreen(roomCode: code, isHost: isHost)),
    );
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final code = await _roomService.createRoom();
      if (mounted) _openRoom(code, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      showError(context, ServerException('6 belgili kod kiriting'));
      return;
    }
    setState(() => _loading = true);
    try {
      final joined = await _roomService.joinRoom(code);
      if (!joined) {
        if (mounted) {
          showError(context, ServerException("Xona topilmadi yoki to'la"));
        }
        return;
      }
      _codeController.clear();
      if (mounted) _openRoom(code, false);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyinim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<Doc>(
            stream: _server.watch('me'),
            builder: (context, snap) {
              final me = snap.data?.data();
              final name = (me?['name'] as String?) ?? _server.myName;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _create,
            child: const Text('Xona ochish'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Xona kodi',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loading ? null : _join,
                child: const Text('Kirish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
