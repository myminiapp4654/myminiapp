import 'package:flutter/material.dart';

import '../net/server_client.dart';

/// Server bilan aloqa uzilsa yuqorida ogohlantirish chiqaradi.
class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final server = ServerClient.instance;
    return ValueListenableBuilder<ConnState>(
      valueListenable: server.state,
      builder: (context, state, _) {
        // Birinchi ulanishda emas, faqat kirgandan keyin uzilsa
        final offline =
            server.user.value != null && state != ConnState.online;
        return Column(
          children: [
            if (offline)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: SafeArea(
                  bottom: false,
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.wifi_off),
                    title: const Text("Aloqa yo'q, qayta ulanmoqda..."),
                    trailing: TextButton(
                      onPressed: server.retryNow,
                      child: const Text('Qayta'),
                    ),
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
