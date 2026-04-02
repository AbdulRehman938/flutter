import 'dart:async';

import 'package:flutter/material.dart';

class TopToast {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissActive();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final entry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;
        return Positioned(
          top: topPadding + 12,
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: true,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB91C1C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, _dismissActive);
  }

  static void _dismissActive() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}
