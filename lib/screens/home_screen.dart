import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../net/server_client.dart';
import '../services/audio_service.dart';
import '../services/room_service.dart';
import '../telegram/telegram.dart';
import '../theme/pixel_ui.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Telegram havolasidagi xona kodi faqat bir marta ishlatiladi
  static bool _startParamUsed = false;

  final _server = ServerClient.instance;
  final _roomService = RoomService();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _musicOn = true;

  late final AnimationController _introCtrl;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _joinFromTelegramLink();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  /// t.me/bot/app?startapp=KOD havolasi orqali kelganda xonaga avtomatik kiradi.
  void _joinFromTelegramLink() {
    if (_startParamUsed) return;
    final code = Telegram.startParam?.trim().toUpperCase();
    if (code == null || code.length != 6) return;
    _startParamUsed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _codeController.text = code;
      _joinGameRoom();
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    final text = e is ServerException ? e.message : 'Xatolik: $e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createGameRoom() async {
    Telegram.haptic();
    setState(() => _isLoading = true);
    try {
      final code = await _roomService.createRoom();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RoomScreen(roomCode: code, isHost: true)),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGameRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError(ServerException('6 belgili kod kiriting'));
      return;
    }
    Telegram.haptic();
    setState(() => _isLoading = true);
    try {
      final joined = await _roomService.joinRoom(code);
      if (!joined) {
        _showError(ServerException("Xona topilmadi yoki to'la"));
        return;
      }
      _codeController.clear();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RoomScreen(roomCode: code, isHost: false)),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: kBorder, width: 2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pixelText('[ QANDAY O\'YNALADI ]', kWarn, 15),
              const SizedBox(height: 14),
              pixelText(
                "1. XONA OCHING\n"
                "2. ✈ TUGMASI BILAN DO'STNI CHAQIRING\n"
                "3. O'YIN TANLANG VA O'YNANG!",
                kWhite,
                11,
              ),
              const SizedBox(height: 18),
              pixelText("Muammo bo'lsa adminga yozing:", kDim, 11),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  const link = 'https://t.me/Ulugbeck_dev';
                  if (Telegram.isAvailable) {
                    Telegram.openLink(link);
                    return;
                  }
                  final uri = Uri.parse(link);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    Clipboard.setData(const ClipboardData(text: link));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Link nusxalandi!')),
                      );
                    }
                  }
                },
                child: pixelContainer(
                  borderColor: kBlue,
                  color: kBlue.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      pixelText('✈', kBlue, 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: pixelText('@Ulugbeck_dev', kBlue, 13,
                            align: TextAlign.left),
                      ),
                      const Icon(Icons.open_in_new, color: kBlue, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              pixelButton(
                label: 'YOPISH',
                onTap: () => Navigator.pop(ctx),
                color: kBg,
                textColor: kDim,
                borderColor: kBorder,
                fontSize: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pastdan yuqoriga chiqib keladigan animatsiya (har bir blok ketma-ket).
  Widget _intro(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: _introCtrl,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPanel,
        automaticallyImplyLeading: false,
        title: pixelText('[ OYINIM ]', kAccent, 16),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.help_outline, color: kDim),
          onPressed: _showHelpDialog,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _musicOn ? Icons.music_note : Icons.music_off,
              color: _musicOn ? kWarn : kDim,
            ),
            onPressed: () {
              setState(() => _musicOn = !_musicOn);
              AudioService.instance.toggle();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intro(0, _buildProfileCard()),
            const SizedBox(height: 24),
            _intro(
              1,
              pixelText('// O\'YIN XONASI', kDim, 11, align: TextAlign.left),
            ),
            const SizedBox(height: 10),
            _intro(
              2,
              pixelButton(
                label: _isLoading ? 'YUKLANMOQDA...' : '+ YANGI XONA OCHISH',
                onTap: _isLoading ? null : _createGameRoom,
                color: kAccent,
                textColor: kBg,
                borderColor: kAccent,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 10),
            _intro(3, _buildJoinRow()),
            const SizedBox(height: 28),
            _intro(4, _buildGamesPreview()),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return StreamBuilder<Doc>(
      stream: _server.watch('me'),
      builder: (context, snap) {
        final me = snap.data?.data();
        final name = ((me?['name'] as String?) ?? _server.myName).toUpperCase();
        final stars = (me?['stars'] as int?) ?? 0;
        final level = ((me?['wordPuzzleLevel'] as int?) ?? 0) + 1;
        return pixelContainer(
          borderColor: kAccent,
          color: kAccent.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kAccentDim,
                  border: Border.all(color: kAccent, width: 2),
                ),
                child: Center(
                  child: pixelText(name.isNotEmpty ? name[0] : '?', kWhite, 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pixelText(name, kWhite, 15, align: TextAlign.left),
                    const SizedBox(height: 4),
                    pixelText("SO'Z TOPISH: $level-DARAJA", kDim, 10,
                        align: TextAlign.left),
                  ],
                ),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: stars),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, _) => pixelContainer(
                  borderColor: kWarn,
                  color: kWarn.withValues(alpha: 0.1),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: pixelText('★ $value', kWarn, 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            style: const TextStyle(
                color: kWhite,
                fontSize: 16,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace'),
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 6,
            decoration: pixelInputDecoration('XONA KODI'),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            onSubmitted: (_) => _joinGameRoom(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isLoading ? null : _joinGameRoom,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kPanel,
              border: Border.all(color: kWarn, width: 2),
              boxShadow: [
                BoxShadow(
                    color: kWarn.withValues(alpha: 0.4),
                    blurRadius: 0,
                    offset: const Offset(3, 3)),
              ],
            ),
            child: Center(child: pixelText('KIRISH', kWarn, 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildGamesPreview() {
    const games = [
      ('✖', 'X-O', kBlue),
      ('♟', 'SHASHKA', kWarn),
      ('?', 'QUIZ', kAccent),
      ('!', "HA/YO'Q", Color(0xFF00CCFF)),
      ('A', "SO'Z TOPISH", kAccent),
      ('#', 'HARFLAR', kDanger),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pixelText("// O'YINLAR", kDim, 11, align: TextAlign.left),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in games)
              pixelContainer(
                borderColor: g.$3.withValues(alpha: 0.5),
                color: g.$3.withValues(alpha: 0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    pixelText(g.$1, g.$3, 14),
                    const SizedBox(width: 6),
                    pixelText(g.$2, g.$3, 10),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        pixelText(
          "XONA OCHING VA DO'STINGIZNI CHAQIRING — O'YINNI XONADA TANLAYSIZ",
          kDim,
          10,
          align: TextAlign.left,
        ),
      ],
    );
  }
}
