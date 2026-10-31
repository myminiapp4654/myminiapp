import 'package:flutter/material.dart';

import '../net/server_client.dart';
import '../telegram/telegram.dart';
import '../ui/kit.dart';

/// Faqat admin uchun: botga kirganlar va o'yinni ochganlar.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _bot = const [];
  List<Map<String, dynamic>> _app = const [];
  int _now = DateTime.now().millisecondsSinceEpoch;
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ServerClient.instance.call<Map>('admin.users');
      setState(() {
        _bot = [for (final e in (r?['bot'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
        _app = [for (final e in (r?['app'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
        _now = r?['now'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Toshkent vaqti bilan: "31.10 12:38".
  static String _date(int? ms) {
    if (ms == null) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toUtc().add(const Duration(hours: 5));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  int _recent(List<Map<String, dynamic>> list) {
    final day = _now - const Duration(days: 1).inMilliseconds;
    return list.where((u) => ((u['last'] as int?) ?? 0) > day).length;
  }

  @override
  Widget build(BuildContext context) {
    final list = (_showApp ? _app : _bot).where((u) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return '${u['name']} ${u['username'] ?? ''} ${u['id'] ?? u['uid']}'.toLowerCase().contains(q);
    }).toList();

    return GameScaffold(
      title: 'Foydalanuvchilar',
      palette: GamePalette.home,
      actions: [
        IconButton(tooltip: 'Yangilash', icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Row(
                        children: [
                          _stat('Botga kirgan', '${_bot.length}', const Color(0xFF4FC3F7)),
                          _stat('24 soatda', '${_recent(_bot)}', const Color(0xFF66BB6A)),
                          _stat("O'yin ochgan", '${_app.length}', const Color(0xFFFFC233)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          _tab('Botga kirganlar', !_showApp, () => setState(() => _showApp = false)),
                          const SizedBox(width: 8),
                          _tab("O'yinni ochganlar", _showApp, () => setState(() => _showApp = true)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v.trim()),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ism, @username yoki ID',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text("Hali hech kim yo'q", style: TextStyle(color: Colors.white54)))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                                itemCount: list.length,
                                itemBuilder: (_, i) => _row(list[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: active ? Colors.white38 : Colors.white12),
            ),
            child: Text(label,
                style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: FontWeight.w800)),
          ),
        ),
      );

  Widget _row(Map<String, dynamic> u) {
    final name = (u['name'] as String?)?.trim();
    final username = u['username'] as String?;
    final id = '${u['id'] ?? (u['uid'] as String? ?? '').replaceFirst('tg', '')}';
    final initial = (name == null || name.isEmpty) ? '?' : name.characters.first.toUpperCase();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF7B5CFF),
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name == null || name.isEmpty ? 'Ismsiz' : name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    if (username != null)
                      GestureDetector(
                        onTap: () => Telegram.openLink('https://t.me/$username'),
                        child: Text('@$username  ',
                            style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 12)),
                      ),
                    Flexible(
                      child: Text('ID $id',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_date(u['last'] as int?), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              if (u['starts'] != null)
                Text('Start: ${u['starts']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
