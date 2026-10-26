import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

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
              t['whoWorks'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 14),
            for (final row in app.liveBoard) ...[
              _LiveRow(
                employeeId: row.employeeId,
                sub: row.sub,
                hours: row.hours,
                onShift: row.onShift,
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 8),
            SecondaryButton(
              label: t['fixClock'],
              onPressed: app.liveBoard.isEmpty
                  ? null
                  : () => app.fixClockEntry(app.liveBoard.first.employeeId),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({
    required this.employeeId,
    required this.sub,
    required this.hours,
    required this.onShift,
  });

  final String employeeId;
  final String sub;
  final String hours;
  final bool onShift;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final emp = app.employeeById(employeeId);

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: onShift ? AppColors.green : const Color(0xFF3A3F36),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          InitialsAvatar(
            initials: emp.initials,
            paletteIndex: emp.avatarIndex,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.name,
                  style: AppTextStyles.sans(size: 14.5, weight: FontWeight.w600),
                ),
                Text(sub, style: AppTextStyles.mono(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            hours,
            style: AppTextStyles.mono(
              size: 13,
              weight: FontWeight.w700,
              color: onShift ? AppColors.lime : const Color(0xFF5C6357),
            ),
          ),
        ],
      ),
    );
  }
}
