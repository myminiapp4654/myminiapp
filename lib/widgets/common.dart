import 'package:flutter/material.dart';

import '../net/server_client.dart';

/// Yuklanish ekrani.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Xona yoki o'yin o'chirilganda ko'rsatiladi.
class ClosedScreen extends StatelessWidget {
  const ClosedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Xona yopildi"),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Orqaga'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Xatoni pastda qisqa xabar qilib ko'rsatadi.
void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final text = error is ServerException ? error.message : 'Xatolik: $error';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Server amalini bajaradi, xato bo'lsa xabar chiqaradi.
Future<void> runAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
