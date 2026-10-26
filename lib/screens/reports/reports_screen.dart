import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Text(
              t['reports'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              app.periodLabel,
              style: AppTextStyles.mono(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['totalHours'].toUpperCase(),
                        style: AppTextStyles.eyebrow(
                          color: AppColors.ink.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        app.totalHoursLabel,
                        style: AppTextStyles.mono(
                          size: 34,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        app.estimatedCostLabel,
                        style: AppTextStyles.mono(
                          size: 17,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['estCost'],
                        style: AppTextStyles.sans(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.ink.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final e in app.employees) ...[
              _EmployeeBar(
                name: e.name,
                hoursLabel: e.hoursLabel,
                overtime: e.hoursWorked > AppState.overtimeThresholdHours,
                fraction: (e.hoursWorked / 75).clamp(0, 1),
                overtimeLabel: t['overtime'],
              ),
              const SizedBox(height: 11),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(label: 'CSV', onPressed: app.exportCsv),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(label: 'PDF', onPressed: app.exportPdf),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeBar extends StatelessWidget {
  const _EmployeeBar({
    required this.name,
    required this.hoursLabel,
    required this.overtime,
    required this.fraction,
    required this.overtimeLabel,
  });

  final String name;
  final String hoursLabel;
  final bool overtime;
  final double fraction;
  final String overtimeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: AppTextStyles.sans(size: 13.5, weight: FontWeight.w600)),
            Row(
              children: [
                if (overtime) ...[
                  Text(
                    overtimeLabel.toUpperCase(),
                    style: AppTextStyles.mono(
                      size: 9.5,
                      letterSpacing: 0.8,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  hoursLabel,
                  style: AppTextStyles.mono(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: const Color(0xFF1F241C),
            valueColor: AlwaysStoppedAnimation(
              overtime ? AppColors.amber : AppColors.lime,
            ),
          ),
        ),
      ],
    );
  }
}
