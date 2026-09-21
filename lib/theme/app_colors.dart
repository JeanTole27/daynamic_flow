import 'package:flutter/material.dart';

/// "Ink & Lime" palette — ported 1:1 from the approved Turnos design
/// (direction 1a in `Turnos - Direcciones visuales.dc.html`).
abstract final class AppColors {
  static const lime = Color(0xFFC6F04B);
  static const limeHover = Color(0xFFD9F97F);
  static const ink = Color(0xFF0E100C);
  static const card = Color(0xFF171A14);
  static const cardAlt = Color(0xFF1F241C);
  static const chipBg = Color(0xFF232821);
  static const border = Color(0x17FFFFFF); // rgba(255,255,255,.09)
  static const borderStrong = Color(0x29FFFFFF); // rgba(255,255,255,.16)
  static const text = Color(0xFFF2F4EE);
  static const muted = Color(0xFF8E958A);
  static const mutedDim = Color(0xFF6C7366);
  static const red = Color(0xFFFF6B4A);
  static const green = Color(0xFF6FE3B0);
  static const amber = Color(0xFFF2B23E);
  static const toastBg = Color(0xFFF2F4EE);
  static const toastFg = ink;

  static const avatarPalette = <(Color bg, Color fg)>[
    (Color(0xFFC6F04B), Color(0xFF0E100C)),
    (Color(0xFF6FE3B0), Color(0xFF0E2A1E)),
    (Color(0xFFF2B23E), Color(0xFF2A1D06)),
    (Color(0xFF8FB8FF), Color(0xFF0B1A33)),
    (Color(0xFFE8A0C8), Color(0xFF2E0C22)),
  ];
}
