import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/lime_switch.dart';
import '../../widgets/section_label.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    final prefLabels = [
      app.isEnglish ? 'Shift reminder (30 min)' : 'Recordatorio de turno (30 min)',
      app.isEnglish ? 'New messages' : 'Mensajes nuevos',
      app.isEnglish ? 'Forgot to clock out' : 'Olvidé marcar salida',
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Row(
              children: [
                const BackPill(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      t['notifications'],
                      style: AppTextStyles.sans(
                        size: 20,
                        weight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: app.markAllNotifsRead,
                  child: Text(
                    t['readAll'],
                    style: AppTextStyles.sans(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.lime,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final n in app.notifs) ...[
              _NotifCard(
                title: n.textFor(app.isEnglish),
                time: n.timeLabel,
                read: n.read,
                onTap: () => app.markNotifRead(n.id),
              ),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 10),
            SectionLabel(t['notifPrefs']),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < prefLabels.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: i == prefLabels.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prefLabels[i],
                              style: AppTextStyles.sans(size: 14),
                            ),
                          ),
                          LimeSwitch(
                            value: app.notifPrefs[i],
                            onChanged: (_) => app.toggleNotifPref(i),
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

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.title,
    required this.time,
    required this.read,
    required this.onTap,
  });

  final String title;
  final String time;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: read ? Colors.transparent : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: read ? AppColors.border : AppColors.lime.withValues(alpha: 0.28),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: read ? const Color(0xFF3A3F36) : AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sans(
                        size: 14,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(time, style: AppTextStyles.mono(size: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
