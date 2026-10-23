import 'dart:ui';

import 'package:flutter/material.dart';

import 'net/server_client.dart';
import 'screens/start_screen.dart';
import 'services/audio_service.dart';
import 'telegram/telegram.dart';
import 'theme/pixel_ui.dart';
import 'widgets/connectivity_wrapper.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.instance.init();
  Telegram.init();

  // Kutilmagan server xatolari (masalan, aloqa uzilganda yurish) —
  // ilova yiqilmasin, foydalanuvchiga xabar chiqsin.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is ServerException) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return true;
    }
    return false;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: kBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: kDanger, size: 48),
              const SizedBox(height: 16),
              pixelText('XATOLIK YUZ BERDI', kWhite, 16),
              const SizedBox(height: 12),
              Text(details.exception.toString(),
                  style: const TextStyle(color: kDim, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oyinim',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kBg,
        useMaterial3: true,
      ),
      builder: (context, child) => ConnectivityWrapper(child: child!),
      home: const StartScreen(),
    );
  }
}
