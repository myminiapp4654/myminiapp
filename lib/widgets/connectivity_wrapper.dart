import 'package:flutter/material.dart';

import '../net/server_client.dart';

/// Server bilan aloqa uzilsa yuqorida qizil banner chiqaradi.

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  final _server = ServerClient.instance;
  bool _isOffline = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _server.state.addListener(_onState);
  }

  void _onState() {
    // Birinchi ulanishda emas, faqat kirgandan keyin uzilsa ko'rsatamiz
    final offline = _server.user.value != null &&
        _server.state.value != ConnState.online;
    if (offline == _isOffline) return;
    setState(() => _isOffline = offline);
    if (offline) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  @override
  void dispose() {
    _server.state.removeListener(_onState);
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        SlideTransition(
          position: _slideAnimation,
          child: _isOffline
              ? _NoInternetBanner(onRetry: _server.retryNow)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _NoInternetBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoInternetBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: const Color(0xFF1A1A2E),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.95),
                  border: const Border(
                    bottom: BorderSide(color: Colors.redAccent, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Server bilan aloqa yo'q — qayta ulanmoqda...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRetry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Qayta',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
