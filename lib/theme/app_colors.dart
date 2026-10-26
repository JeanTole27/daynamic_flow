import 'package:flutter/material.dart';

/// Paleta clara basada en los verdes del logo (#02AD4D → #8DC63F).
abstract final class AppColors {
  /// Verde del logo, un tono más oscuro para que el texto blanco encima se
  /// lea bien (botones, tarjetas destacadas, burbujas propias).
  static const primary = Color(0xFF029A45);

  /// Verde del logo para texto e íconos sobre fondo blanco: más oscuro aún
  /// para cumplir contraste en letra pequeña.
  static const primaryText = Color(0xFF017A36);

  /// Verde claro del extremo del logo — acentos y degradados.
  static const primaryLight = Color(0xFF8DC63F);

  /// Fondo verde muy suave para chips y estados seleccionados.
  static const primarySoft = Color(0xFFE6F6EC);

  /// Texto e íconos sobre [primary].
  static const onPrimary = Color(0xFFFFFFFF);

  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFF4F8F5);
  static const cardAlt = Color(0xFFE9EFEB);
  static const chipBg = primarySoft;
  static const border = Color(0x1F0F3D22);
  static const borderStrong = Color(0x380F3D22);
  static const text = Color(0xFF14231A);
  static const muted = Color(0xFF5B6A61);
  static const mutedDim = Color(0xFF8A968F);

  /// Elementos apagados: temporizador detenido, puntos inactivos, interruptor
  /// apagado.
  static const inactive = Color(0xFFC9D2CC);

  static const red = Color(0xFFD93A2B);
  static const green = Color(0xFF1FB55A);
  static const amber = Color(0xFFC27A00);
  static const toastBg = Color(0xFF14231A);
  static const toastFg = Color(0xFFFFFFFF);

  static const avatarPalette = <(Color bg, Color fg)>[
    (Color(0xFFD7F0DF), Color(0xFF0B6B31)),
    (Color(0xFFE8F4D3), Color(0xFF4A6B12)),
    (Color(0xFFFBEBCB), Color(0xFF7A4A00)),
    (Color(0xFFDCE7FB), Color(0xFF1D3F7A)),
    (Color(0xFFF7DDEA), Color(0xFF7A1E4C)),
  ];
}
