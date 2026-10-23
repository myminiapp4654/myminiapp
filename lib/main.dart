import 'dart:ui';

import 'package:flutter/material.dart';

import 'net/server_client.dart';
import 'screens/start_screen.dart';
import 'telegram/telegram.dart';
import 'widgets/connectivity_wrapper.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Telegram.init();

  // Kutilmagan server xatolari ilovani yiqitmasin — xabar chiqsin
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is ServerException) {
      scaffoldMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(error.message)));
      return true;
    }
    return false;
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
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => ConnectivityWrapper(child: child!),
      home: const StartScreen(),
    );
  }
}
