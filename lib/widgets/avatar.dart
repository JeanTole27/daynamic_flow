import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Initials avatar chip, colored from the design's rotating avatar palette.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.paletteIndex,
    this.size = 36,
    this.fontSize = 12,
  });

  final String initials;
  final int paletteIndex;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) =
        AppColors.avatarPalette[paletteIndex % AppColors.avatarPalette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.33),
      ),
      child: Text(
        initials,
        style: AppTextStyles.mono(
          size: fontSize,
          weight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
