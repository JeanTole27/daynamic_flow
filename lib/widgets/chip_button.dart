import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Pill / box selector chip used in the "new shift" sheet and segmented
/// tabs (who / when / time-of-day pickers).
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: selected ? AppColors.lime : AppColors.cardAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.lime : AppColors.borderStrong,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: mono
                ? AppTextStyles.mono(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: selected ? AppColors.ink : AppColors.text,
                  )
                : AppTextStyles.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.ink : AppColors.text,
                  ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: child) : child;
  }
}

/// Segmented control tab (e.g. Horario / Disponible / Cambios).
class SegmentTab extends StatelessWidget {
  const SegmentTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.sans(
                size: 13,
                weight: FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
