import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/pixel_ui.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      final age = int.parse(_ageController.text.trim());
      final docRef = await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setInt('user_age', age);
      await prefs.setString('user_id', docRef.id);
      if (mounted) {
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pixelText('[ OYINIM ]', kAccent, 28),
                  const SizedBox(height: 8),
                  pixelText('RO\'YXATDAN O\'TING', kDim, 12),
                  const SizedBox(height: 40),
                  pixelContainer(
                    borderColor: kBorder,
                    color: kPanel,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                              color: kWhite,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold),
                          decoration: pixelInputDecoration('ISM KIRITING'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ism kiriting';
                            }
                            if (v.trim().length < 2) return 'Ism kamida 2 harf';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ageController,
                          style: const TextStyle(
                              color: kWhite,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold),
                          keyboardType: TextInputType.number,
                          decoration: pixelInputDecoration('YOSH KIRITING'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Yosh kiriting';
                            }
                            final age = int.tryParse(v.trim());
                            if (age == null) return 'Raqam kiriting';
                            if (age < 5 || age > 100) {
                              return 'Yosh 5-100 orasida bo\'lsin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        pixelButton(
                          label: _isLoading ? 'YUKLANMOQDA...' : '► BOSHLASH',
                          onTap: _isLoading ? null : _register,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
