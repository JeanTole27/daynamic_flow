import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';
import '../shift/new_shift_sheet.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(t['week']),
                      const SizedBox(height: 5),
                      Text(
                        app.weekRangeLabel,
                        style: AppTextStyles.sans(
                          size: 24,
                          weight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.lime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showNewShiftSheet(context),
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.add, color: AppColors.ink, size: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            for (final day in app.week) ...[
              _WeekDayRow(day: day),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 8),
            SecondaryButton(
              label: t['duplicateWeek'],
              onPressed: app.duplicateWeek,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final dd = app.dayLabels[day.weekdayIndex].toUpperCase();

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                children: [
                  Text(
                    dd,
                    style: AppTextStyles.mono(
                      size: 9.5,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  Text(
                    '${day.dayNumber}',
                    style: AppTextStyles.mono(
                      size: 19,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final slot in day.slots) _SlotChip(slot: slot),
                if (day.openCount > 0)
                  Material(
                    color: AppColors.red.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: AppColors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => showNewShiftSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          '${day.openCount} ${t['open'].toLowerCase()}',
                          style: AppTextStyles.mono(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot});

  final ShiftSlot slot;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final emp = app.employeeById(slot.employeeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 11, 6),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InitialsAvatar(
            initials: emp.initials,
            paletteIndex: emp.avatarIndex,
            size: 20,
            fontSize: 9,
          ),
          const SizedBox(width: 6),
          Text(slot.timeLabel, style: AppTextStyles.mono(size: 11)),
        ],
      ),
    );
  }
}
