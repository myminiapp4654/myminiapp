import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/audio_service.dart';
import '../theme/pixel_ui.dart';
import 'login_screen.dart';
import 'room_screen.dart';
import 'chat_rooms_list_screen.dart';
import 'dm_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _roomService = RoomService();
  final _user = FirebaseAuth.instance.currentUser!;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _musicOn = true;
  late Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    _authService.syncDisplayName().catchError((_) {});
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();
  }

  void _refreshUserData() {
    setState(() {
      _userFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createGameRoom() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGameRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('6 belgili kod kiriting')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final joined = await _roomService.joinRoom(code);
      if (!joined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Xona topilmadi yoki to\'la')));
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfileSheet(String currentName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kAccent, width: 2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 2, color: kBorder),
              const SizedBox(height: 12),
              _sheetTile(Icons.edit, 'PROFILNI TAHRIRLASH', kAccent, () {
                Navigator.pop(ctx);
                _showEditNameDialog(currentName);
              }),
              _sheetTile(Icons.help_outline, 'YORDAM', kWarn, () {
                Navigator.pop(ctx);
                _showHelpDialog();
              }),
              _sheetTile(Icons.logout, 'CHIQISH', kDanger, () async {
                Navigator.pop(ctx);
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 14),
            pixelText(label, color, 12, align: TextAlign.left),
          ],
        ),
      ),
    );
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
              pixelText('[ YORDAM ]', kWarn, 16),
              const SizedBox(height: 16),
              pixelText(
                'Xatolik yoki muammo bo\'lsa\nquyidagi adminga murojaat qiling:',
                kDim, 11,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://t.me/Ulugbeck_dev');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    Clipboard.setData(
                        const ClipboardData(text: 'https://t.me/Ulugbeck_dev'));
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            pixelText('@Ulugbeck_dev', kBlue, 13,
                                align: TextAlign.left),
                            pixelText('TELEGRAM', kDim, 10,
                                align: TextAlign.left),
                          ],
                        ),
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

  void _showEditNameDialog(String currentName) {
    _nameController.text = currentName;
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
              pixelText('[ ISMNI O\'ZGARTIRISH ]', kAccent, 13),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(
                    color: kWhite,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold),
                decoration: pixelInputDecoration('YANGI ISM'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: pixelButton(
                      label: 'BEKOR',
                      onTap: () => Navigator.pop(ctx),
                      color: kBg,
                      textColor: kDim,
                      borderColor: kBorder,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: pixelButton(
                      label: 'SAQLASH',
                      onTap: () async {
                        final newName = _nameController.text.trim();
                        if (newName.isEmpty) return;
                        await _authService.updateName(newName);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _refreshUserData();
                      },
                      color: kAccent,
                      textColor: kBg,
                      borderColor: kAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            // Profile card
            FutureBuilder<DocumentSnapshot>(
              future: _userFuture,
              builder: (context, snapshot) {
                String name = _user.displayName ?? 'MEHMON';
                if (snapshot.hasData && snapshot.data!.exists) {
                  final d = snapshot.data!.data() as Map<String, dynamic>;
                  name = (d['name'] ?? name).toString().toUpperCase();
                }
                return GestureDetector(
                  onTap: () => _showProfileSheet(name),
                  child: pixelContainer(
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
                            child: pixelText(
                              name.isNotEmpty ? name[0] : '?',
                              kWhite,
                              20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: pixelText(name, kWhite, 15,
                              align: TextAlign.left),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: kDim, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            pixelText('// O\'YIN XONASI', kDim, 11, align: TextAlign.left),
            const SizedBox(height: 10),

            pixelButton(
              label: _isLoading ? 'YUKLANMOQDA...' : '+ YANGI XONA OCHISH',
              onTap: _isLoading ? null : _createGameRoom,
              color: kAccent,
              textColor: kBg,
              borderColor: kAccent,
              fontSize: 14,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),

            const SizedBox(height: 10),

            Row(
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
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9]')),
                    ],
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
                      borderRadius: BorderRadius.zero,
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
            ),

            const SizedBox(height: 28),

            pixelText('// CHATLAR', kDim, 11, align: TextAlign.left),
            const SizedBox(height: 10),

            _navCard(
              icon: Icons.group,
              title: 'GURUH CHATLAR',
              subtitle: "Xona och yoki mavjudiga qo'shil",
              color: kAccent,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const ChatRoomsListScreen())),
            ),
            const SizedBox(height: 10),
            _navCard(
              icon: Icons.person,
              title: 'SHAXSIY CHATLAR',
              subtitle: "Do'stlar bilan yakkama-yakka",
              color: kBlue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DmListScreen())),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _navCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kPanel,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 0,
                offset: const Offset(3, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: Center(child: Icon(icon, color: color, size: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pixelText(title, color, 13, align: TextAlign.left),
                  const SizedBox(height: 2),
                  pixelText(subtitle, kDim, 10, align: TextAlign.left),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}
