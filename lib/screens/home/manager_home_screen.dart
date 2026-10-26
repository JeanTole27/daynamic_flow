import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';
import '../live/live_screen.dart';
import '../notifications/notifications_screen.dart';
import '../shell/app_shell.dart';
import '../shift/new_shift_sheet.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final pending = app.pendingRequests;

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
                      SectionLabel(app.orgName),
                      const SizedBox(height: 6),
                      Text(app.greeting, style: AppTextStyles.h1()),
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
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    background: AppColors.primary,
                    valueColor: AppColors.onPrimary,
                    value: '${app.workingNowCount}',
                    valueSuffix: '/${app.teamSize}',
                    label: t['workingNow'],
                    labelColor: AppColors.onPrimary.withValues(alpha: 0.72),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LiveScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    background: AppColors.card,
                    border: AppColors.border,
                    valueColor: AppColors.red,
                    value: '${app.uncoveredCount}',
                    label: t['uncovered'],
                    labelColor: AppColors.muted,
                    onTap: () => AppShell.maybeOf(context)?.goToTab(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SectionLabel(t['requests']),
                Text(
                  '${pending.length}',
                  style: AppTextStyles.mono(
                    size: 10.5,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (pending.isEmpty)
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.borderStrong,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['allClear'],
                      style: AppTextStyles.sans(
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t['allClearSub'],
                      style: AppTextStyles.sans(
                        size: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final r in pending) ...[
                    _RequestCard(request: r),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            const SizedBox(height: 6),
            SecondaryButton(
              label: '+ ${t['newShift']}',
              onPressed: () => showNewShiftSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.background,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
    this.valueSuffix = '',
    this.border,
    this.onTap,
  });

  final Color background;
  final Color valueColor;
  final Color labelColor;
  final Color? border;
  final String value;
  final String valueSuffix;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: background,
      borderColor: border,
      radius: 20,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTextStyles.mono(
                size: 30,
                weight: FontWeight.w700,
                color: valueColor,
                letterSpacing: -1.2,
              ),
              children: [
                TextSpan(text: value),
                if (valueSuffix.isNotEmpty)
                  TextSpan(
                    text: valueSuffix,
                    style: AppTextStyles.mono(
                      size: 17,
                      color: valueColor.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.sans(
              size: 12,
              weight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ShiftRequest request;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final emp = app.employeeById(request.employeeId);

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(
                initials: emp.initials,
                paletteIndex: emp.avatarIndex,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.requestTitle(request),
                      style: AppTextStyles.sans(
                        size: 14.5,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.requestSubtitle(request),
                      style: AppTextStyles.mono(
                        size: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: t['approve'],
                  dense: true,
                  onPressed: () => app.approveRequest(request.id),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DangerOutlineButton(
                  label: t['reject'],
                  dense: true,
                  onPressed: () => app.rejectRequest(request.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
