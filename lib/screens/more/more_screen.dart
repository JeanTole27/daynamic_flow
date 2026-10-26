import 'package:flutter/material.dart';

import '../../i18n/app_lang.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';
import '../live/live_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    final items = <(String label, WidgetBuilder builder)>[
      (t['reports'], (_) => const ReportsScreen()),
      (t['whoWorks'], (_) => const LiveScreen()),
      (t['notifications'], (_) => const NotificationsScreen()),
      (t['myProfile'], (_) => const ProfileScreen()),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          children: [
            Text(t['more'], style: AppTextStyles.h1()),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _MoreRow(
                      label: items[i].$1,
                      isLast: i == items.length - 1,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: items[i].$2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionLabel(t['language']),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SegmentTab(
                    label: 'Español',
                    selected: app.lang == AppLang.es,
                    onTap: () => app.setLang(AppLang.es),
                  ),
                  SegmentTab(
                    label: 'English',
                    selected: app.lang == AppLang.en,
                    onTap: () => app.setLang(AppLang.en),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Cambiar de rol solo existe en el demo: con backend el rol lo
            // decide la base de datos.
            if (app.isDemo)
            Material(
              color: AppColors.lime.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.lime.withValues(alpha: 0.35)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: app.switchRole,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    t['switchRole'],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sans(
                      size: 14.5,
                      weight: FontWeight.w600,
                      color: AppColors.lime,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.label, required this.isLast, required this.onTap});

  final String label;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.sans(size: 15, weight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedDim, size: 18),
          ],
        ),
      ),
    );
  }
}
