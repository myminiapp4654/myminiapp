import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/pixel_ui.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showAnonForm = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google xatolik: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final user = await _authService.signInAnonymously(name, age);
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                pixelText('[ OYINIM ]', kAccent, 32),
                const SizedBox(height: 8),
                pixelText('RETRO MULTIPLAYER', kDim, 12),
                const SizedBox(height: 48),

                // Google button
                pixelButton(
                  label: 'G  GOOGLE BILAN KIRISH',
                  onTap: _isLoading ? null : _signInWithGoogle,
                  color: kPanel,
                  textColor: kWhite,
                  borderColor: kBlue,
                  fontSize: 14,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),

                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Container(height: 1, color: kBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: pixelText('YOKI', kDim, 10),
                  ),
                  Expanded(
                      child: Container(height: 1, color: kBorder)),
                ]),
                const SizedBox(height: 16),

                if (!_showAnonForm)
                  pixelButton(
                    label: '> MEHMON SIFATIDA',
                    onTap: () => setState(() => _showAnonForm = true),
                    color: kBg,
                    textColor: kDim,
                    borderColor: kBorder,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),

                if (_showAnonForm) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                              color: kWhite,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold),
                          decoration:
                              pixelInputDecoration('ISMINGIZ', icon: Icons.person),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'ISM KIRITING';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ageController,
                          style: const TextStyle(
                              color: kWhite,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold),
                          keyboardType: TextInputType.number,
                          decoration:
                              pixelInputDecoration('YOSHINGIZ', icon: Icons.cake),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'YOSH KIRITING';
                            final age = int.tryParse(v.trim());
                            if (age == null || age < 5 || age > 100) {
                              return '5-100 ORASIDA';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        pixelButton(
                          label: _isLoading ? 'YUKLANMOQDA...' : '► BOSHLASH',
                          onTap: _isLoading ? null : _signInAnonymously,
                          color: kAccent,
                          textColor: kBg,
                          borderColor: kAccent,
                          fontSize: 15,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
