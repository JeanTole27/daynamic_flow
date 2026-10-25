import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final emp = app.employeeById(employeeId);
    final en = app.isEnglish;

    final rows = <(String, String)>[
      (t['position'], emp.roleFor(en)),
      (t['hourlyRate'], emp.rate),
      (t['shiftsThisWeek'], '4'),
      (t['availability'], t['days5']),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Row(
              children: [
                InitialsAvatar(
                  initials: emp.initials,
                  paletteIndex: emp.avatarIndex,
                  size: 60,
                  fontSize: 19,
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: AppTextStyles.sans(
                        size: 23,
                        weight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      emp.roleFor(en),
                      style: AppTextStyles.sans(
                        size: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.hoursLabel.split(' ').first,
                          style: AppTextStyles.mono(
                            size: 22,
                            weight: FontWeight.w700,
                            color: AppColors.lime,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t['thisFortnight'],
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.rate,
                          style: AppTextStyles.mono(
                            size: 22,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t['perHour'],
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              radius: 18,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: i == rows.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rows[i].$1,
                            style: AppTextStyles.sans(
                              size: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(rows[i].$2, style: AppTextStyles.mono(size: 13.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: t['save'],
                    onPressed: () => app.saveEmployeeChanges(emp.id),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DangerOutlineButton(
                    label: t['deactivate'],
                    onPressed: () => app.deactivateEmployee(emp.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
