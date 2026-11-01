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
                  color: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showNewShiftSheet(context),
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.add,
                        color: AppColors.onPrimary,
                        size: 24,
                      ),
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
                for (final slot in day.slots)
                  _SlotChip(
                    slot: slot,
                    openLabel: t['open'],
                    onTap: () {
                      final shift = app.shiftById(slot.shiftId);
                      if (shift != null) showEditShiftSheet(context, shift);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Un turno del día. Los sin cubrir van en rojo. Al tocarlo se edita.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.openLabel,
    required this.onTap,
  });

  final ShiftSlot slot;
  final String openLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final employeeId = slot.employeeId;
    final open = employeeId == null;
    return Material(
      color: open ? AppColors.red.withValues(alpha: 0.08) : AppColors.chipBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: open
            ? BorderSide(color: AppColors.red.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(open ? 11 : 6, 6, 11, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (open)
                Text(
                  '${openLabel.toUpperCase()} ',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.red,
                  ),
                )
              else ...[
                InitialsAvatar(
                  initials: app.employeeById(employeeId).initials,
                  paletteIndex: app.employeeById(employeeId).avatarIndex,
                  size: 20,
                  fontSize: 9,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                slot.timeLabel,
                style: AppTextStyles.mono(
                  size: 11,
                  color: open ? AppColors.red : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
