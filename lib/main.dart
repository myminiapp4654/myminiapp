import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/connectivity_wrapper.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'telegram/telegram.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AudioService.instance.init();
  Telegram.init();
  await _telegramAutoLogin();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('Xatolik yuz berdi',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(details.exception.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  };
  runApp(const MyApp());
}

/// Telegram ichida ochilsa, login ekranini ko'rsatmasdan
/// foydalanuvchini Telegram ismi bilan avtomatik kiritadi.
Future<void> _telegramAutoLogin() async {
  final tgUser = Telegram.user;
  if (tgUser == null) return;
  try {
    // Vebda saqlangan sessiya tiklanishini kutamiz
    final existing = await FirebaseAuth.instance.authStateChanges().first;
    if (existing != null) return;
    await AuthService().signInWithTelegram(
      telegramId: tgUser.id,
      name: tgUser.fullName,
      username: tgUser.username,
    );
  } catch (_) {
    // Xato bo'lsa oddiy login ekrani ochiladi
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oyinim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) => ConnectivityWrapper(child: child!),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF1A1A2E),
              body: Center(
                child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
              ),
            );
          }
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
