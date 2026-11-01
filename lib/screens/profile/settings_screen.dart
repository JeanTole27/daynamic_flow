import 'package:flutter/material.dart';

import '../../i18n/app_lang.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';
import '../login_screen.dart';
import '../notifications/notifications_screen.dart';

/// Ajustes de la cuenta: idioma, avisos y eliminar la cuenta.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _confirmDelete = false;

  Future<void> _delete() async {
    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await app.deleteAccount();
    if (!ok || !mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final sole = app.isSoleManager;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Text(
              t['settings'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
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
                  for (final lang in AppLang.values)
                    SegmentTab(
                      label: lang.label,
                      selected: app.lang == lang,
                      onTap: () => app.setLang(lang),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t['notifications'],
                      style: AppTextStyles.sans(
                        size: 15,
                        weight: FontWeight.w500,
                      ),
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
            const SizedBox(height: 28),
            SectionLabel(t['deleteAccount'], color: AppColors.red),
            const SizedBox(height: 8),
            Text(
              sole
                  ? t.fmt('deleteAccountSoleManager', {'org': app.orgName})
                  : t['deleteAccountInfo'],
              style: AppTextStyles.body(),
            ),
            const SizedBox(height: 12),
            if (!_confirmDelete)
              DangerOutlineButton(
                label: t['deleteAccount'],
                onPressed: app.busy
                    ? null
                    : () => setState(() => _confirmDelete = true),
              )
            else ...[
              Text(
                t['deleteAccountConfirm'],
                style: AppTextStyles.sans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: t['cancel'],
                      onPressed: app.busy
                          ? null
                          : () => setState(() => _confirmDelete = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DangerOutlineButton(
                      label: app.busy ? '…' : t['deleteAccountYes'],
                      onPressed: app.busy ? null : _delete,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
