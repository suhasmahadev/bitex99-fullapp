import 'dart:async';

import 'package:flutter/material.dart';

class OrderNotificationBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onTap;
  final Duration duration;

  const OrderNotificationBanner({
    super.key,
    required this.message,
    this.onTap,
    this.duration = const Duration(seconds: 4),
  });

  static void show(
    BuildContext context, {
    required String message,
    VoidCallback? onTap,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => OrderNotificationBanner(
        message: message,
        onTap: () {
          entry.remove();
          onTap?.call();
        },
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 4600), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  State<OrderNotificationBanner> createState() => _OrderNotificationBannerState();
}

class _OrderNotificationBannerState extends State<OrderNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _timer = Timer(widget.duration, () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offset,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                widget.message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
