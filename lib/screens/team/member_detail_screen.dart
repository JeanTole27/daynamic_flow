import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../chat/chat_screen.dart';

class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final emp = app.employeeById(employeeId);
    final en = app.isEnglish;

    final rows = <(String, Widget)>[
      (t['position'], _value(emp.roleFor(en))),
      (t['hourlyRate'], _value(app.rateLabel(emp))),
      (t['shiftsThisWeek'], _value('${app.shiftsThisWeekOf(emp.id)}')),
      (
        t['availability'],
        FutureBuilder<List<bool>>(
          future: app.availabilityOf(emp.id),
          builder: (_, snap) => _value(
            snap.hasData
                ? t.fmt('availDaysN', {'n': snap.data!.where((d) => d).length})
                : '…',
          ),
        ),
      ),
    ];
    final isMe = emp.id == app.me.id;
    final inactive = emp.status == EmployeeStatus.inactive;

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
                          app.rateLabel(emp),
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
                          rows[i].$2,
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
                    label: t['directMessage'],
                    onPressed: isMe || inactive
                        ? null
                        : () => _openChat(context, app, emp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: inactive
                      ? SecondaryButton(
                          label: t['activate'],
                          onPressed: isMe
                              ? null
                              : () => app.setEmployeeStatus(
                                  emp.id,
                                  EmployeeStatus.active,
                                ),
                        )
                      : DangerOutlineButton(
                          label: t['deactivate'],
                          onPressed: isMe
                              ? null
                              : () => _confirmDeactivate(context, app, emp),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _value(String text) => Text(text, style: AppTextStyles.mono(size: 13.5));

  Future<void> _openChat(
    BuildContext context,
    AppState app,
    Employee emp,
  ) async {
    final navigator = Navigator.of(context);
    final threadId = await app.openDirectThreadWith(emp.id);
    if (threadId == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(threadKey: threadId, title: emp.name),
      ),
    );
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    AppState app,
    Employee emp,
  ) async {
    final t = app.strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        content: Text(
          t.fmt('confirmDeactivate', {'name': emp.name}),
          style: AppTextStyles.sans(size: 14.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t['deactivate'],
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (ok == true) app.deactivateEmployee(emp.id);
  }
}
