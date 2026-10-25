import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/pulse_dot.dart';
import '../../widgets/section_label.dart';
import '../clock/clock_screen.dart';
import '../notifications/notifications_screen.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final en = app.isEnglish;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(t['todayIs']),
                      const SizedBox(height: 6),
                      Text(t['helloAna'], style: AppTextStyles.h1()),
                    ],
                  ),
                ),
                IconPillButton(
                  icon: Icons.notifications_none_rounded,
                  badge: app.hasUnreadNotifs,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['nextShift'].toUpperCase(),
                    style: AppTextStyles.eyebrow(
                      color: AppColors.ink.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '09:00',
                    style: AppTextStyles.mono(
                      size: 40,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t['untilFive']} · ${t['waitress']}',
                    style: AppTextStyles.sans(
                      size: 14.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.only(top: 13),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x290E100C)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const PulseDot(),
                        const SizedBox(width: 7),
                        Text(
                          t['startsIn'],
                          style: AppTextStyles.sans(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClockScreen()),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.clockedIn ? t['clockCardOut'] : t['clockCardIn'],
                          style: AppTextStyles.sans(
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          app.clockedIn
                              ? AppState.formatElapsed(app.elapsed)
                              : t['clockCardSubIn'],
                          style: AppTextStyles.mono(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionLabel(t['thisWeek']),
            const SizedBox(height: 9),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
                      child: _DayPill(
                        label: app.dayLabels[i].substring(0, 2),
                        date: i + 1,
                        active: AppState.employeeShiftDays.contains(i),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SectionLabel(t['pendingYou']),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          en
                              ? "Luis wants your Saturday shift"
                              : 'Luis quiere tu turno del sábado',
                          style: AppTextStyles.sans(
                            size: 13.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          en ? 'Sat 12 · 7:00–3:00' : 'Sáb 12 · 07:00–15:00',
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          en
                              ? 'Confirm next week availability'
                              : 'Confirma tu disponibilidad',
                          style: AppTextStyles.sans(
                            size: 13.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          en ? 'Closes Wednesday' : 'Cierra el miércoles',
                          style: AppTextStyles.sans(
                            size: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.label,
    required this.date,
    required this.active,
  });

  final String label;
  final int date;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.mono(
            size: 9,
            weight: FontWeight.w500,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.lime : Colors.transparent,
            border: active
                ? null
                : Border.all(
                    color: AppColors.borderStrong,
                    style: BorderStyle.solid,
                  ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$date',
            style: AppTextStyles.mono(
              size: 11,
              weight: FontWeight.w700,
              color: active ? AppColors.ink : const Color(0xFF5C6357),
            ),
          ),
        ),
      ],
    );
  }
}
