import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Global key so `AppState` can show the themed toast from anywhere
/// (business-logic methods don't carry a [BuildContext]), mirroring the
/// `flash()` helper in the original design prototype.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Navegador raíz: el aviso se dibuja en su capa superior, por encima de
/// formularios inferiores y diálogos (un SnackBar quedaría detrás).
final rootNavigatorKey = GlobalKey<NavigatorState>();

OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// Muestra un aviso breve abajo de la pantalla, encima de todo lo abierto.
/// Reemplaza al anterior si aún se ve. No hace nada sin app montada (tests).
void showAppToast(String message) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _hideToast();
  final entry = OverlayEntry(
    builder: (context) => _Toast(message: message, onDismiss: _hideToast),
  );
  _toastEntry = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(seconds: 4), _hideToast);
  // Lectores de pantalla: el aviso no recibe el foco, así que se anuncia.
  final view = View.maybeOf(overlay.context);
  if (view != null) {
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  }
}

void _hideToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _toastEntry?.remove();
  _toastEntry = null;
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Por encima del teclado si está abierto.
    final bottom = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom + 12
        : media.padding.bottom + 16;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        ),
        child: Material(
          color: AppColors.toastBg,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                message,
                style: AppTextStyles.sans(
                  size: 13.5,
                  weight: FontWeight.w600,
                  color: AppColors.toastFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
