import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Solid lime pill button — the app's single primary action color.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: disabled ? AppColors.cardAlt : AppColors.lime,
          foregroundColor: disabled ? AppColors.mutedDim : AppColors.ink,
          disabledBackgroundColor: AppColors.cardAlt,
          disabledForegroundColor: AppColors.mutedDim,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: dense ? 13 : 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dense ? 13 : 16),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.sans(
            size: dense ? 13.5 : 16,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Outlined button on dark card — secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: EdgeInsets.symmetric(vertical: dense ? 13 : 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dense ? 13 : 16),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.sans(
            size: dense ? 13.5 : 15,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Red-outline destructive button (Rechazar / Desactivar).
class DangerOutlineButton extends StatelessWidget {
  const DangerOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.red,
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
          padding: EdgeInsets.symmetric(vertical: dense ? 13 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dense ? 13 : 15),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.sans(
            size: dense ? 13 : 14.5,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Round back-chevron button used at the top of pushed screens.
class BackPill extends StatelessWidget {
  const BackPill({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.chevron_left, color: AppColors.muted, size: 22),
        ),
      ),
    );
  }
}
