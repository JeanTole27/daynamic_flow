import 'package:flutter/material.dart';

import '../../i18n/app_lang.dart';
import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';
import '../login_screen.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final isManager = app.role == UserRole.manager;
    final initials = isManager ? 'CV' : 'AT';
    final name = isManager ? 'Carlos Vega' : 'Ana Torres';
    final roleLine = isManager
        ? '${t['manager']} · El Roble'
        : '${t['waitress']} · El Roble';

    final items = <(String label, VoidCallback onTap)>[
      (t['changePass'], () => app.flash(app.isEnglish ? 'Coming soon' : 'Próximamente')),
      (
        t['notifications'],
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
      (t['settings'], () => app.flash(app.isEnglish ? 'Coming soon' : 'Próximamente')),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Text(
                    initials,
                    style: AppTextStyles.mono(
                      size: 20,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.sans(
                        size: 23,
                        weight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(roleLine, style: AppTextStyles.sans(size: 13, color: AppColors.muted)),
                  ],
                ),
              ],
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    InkWell(
                      onTap: items[i].$2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 17,
                        ),
                        decoration: BoxDecoration(
                          border: i == items.length - 1
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: AppColors.border),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                items[i].$1,
                                style: AppTextStyles.sans(size: 15),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.mutedDim,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
            TextButton(
              onPressed: () {
                app.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: Text(
                t['logout'],
                style: AppTextStyles.sans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
