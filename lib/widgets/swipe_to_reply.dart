import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({super.key, required this.child, required this.onReply});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _offset = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx < 0) {
          setState(() {
            _offset = max(-64.0, _offset + d.delta.dx);
            if (_offset <= -52 && !_triggered) {
              _triggered = true;
              HapticFeedback.lightImpact();
            }
          });
        }
      },
      onHorizontalDragEnd: (_) {
        if (_triggered) widget.onReply();
        setState(() {
          _offset = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 6,
            child: AnimatedOpacity(
              opacity: _offset < -10 ? min(1.0, (-_offset - 10) / 42) : 0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.reply, color: Colors.white54, size: 16),
              ),
            ),
          ),
          AnimatedContainer(
            duration:
                _offset == 0 ? const Duration(milliseconds: 180) : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
