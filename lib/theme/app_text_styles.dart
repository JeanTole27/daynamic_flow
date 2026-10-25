import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Text styles ported from the design.
///
/// The design specifies "Space Grotesk" for UI copy and "JetBrains Mono"
/// for data-heavy text (timers, hours, amounts). Real font files are not
/// bundled in this project yet — drop the .ttf assets under
/// `assets/fonts/` and register the `SpaceGrotesk` / `JetBrainsMono`
/// families in pubspec.yaml, then swap the `fontFamily` below. Until then
/// this falls back to the platform default / monospace so nothing here
/// depends on network font fetching.
abstract final class AppTextStyles {
  static const _sans = TextStyle(fontFamily: 'SpaceGrotesk');
  static const _mono = TextStyle(fontFamily: 'JetBrainsMono');

  static TextStyle sans({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double letterSpacing = 0,
    double? height,
  }) => _sans.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.text,
    double letterSpacing = 0,
  }) => _mono.copyWith(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// Small uppercase mono label used for section headers / eyebrow text.
  static TextStyle eyebrow({Color color = AppColors.muted}) => mono(
    size: 10.5,
    weight: FontWeight.w500,
    color: color,
    letterSpacing: 1.5,
  );

  static TextStyle h1({double size = 27}) => sans(
    size: size,
    weight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static TextStyle body({Color color = AppColors.muted}) =>
      sans(size: 14.5, color: color, height: 1.45);
}
