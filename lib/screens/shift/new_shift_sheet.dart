import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';

Future<void> showNewShiftSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _NewShiftSheet(),
  );
}

class _NewShiftSheet extends StatefulWidget {
  const _NewShiftSheet();

  @override
  State<_NewShiftSheet> createState() => _NewShiftSheetState();
}

class _NewShiftSheetState extends State<_NewShiftSheet> {
  int _who = 0;
  int? _day;
  int _time = 0;
  int _site = 0;

  static const _times = ['09–17', '14–22', '17–01'];

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final days = app.dayLabels;
    final people = app.assignableEmployees;
    final sites = app.sites;
    // Por defecto: hoy (no tiene sentido crear turnos en días ya pasados).
    final day = _day ?? app.todayIndex;
    final who = _who < people.length ? _who : 0;
    final site = _site < sites.length ? _site : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderStrong)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t['newShift'],
              style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SectionLabel(t['who']),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < people.length; i++)
                  SelectableChip(
                    label: people[i].firstName,
                    selected: who == i,
                    onTap: () => setState(() => _who = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SectionLabel(t['when']),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 7; i++) ...[
                  SelectableChip(
                    label: days[i].substring(0, 2),
                    selected: day == i,
                    onTap: () => setState(() => _day = i),
                    mono: true,
                    expand: true,
                  ),
                  if (i != 6) const SizedBox(width: 5),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SectionLabel(t['shiftTime']),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _times.length; i++) ...[
                  SelectableChip(
                    label: _times[i],
                    selected: _time == i,
                    onTap: () => setState(() => _time = i),
                    mono: true,
                    expand: true,
                  ),
                  if (i != _times.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            if (sites.length > 1) ...[
              const SizedBox(height: 16),
              SectionLabel(t['site']),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < sites.length; i++)
                    SelectableChip(
                      label: sites[i].name,
                      selected: site == i,
                      onTap: () => setState(() => _site = i),
                    ),
                ],
              ),
            ],
            if (sites.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t['noSites'],
                style: AppTextStyles.sans(size: 12, color: AppColors.red),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: t['assign'],
              onPressed: people.isEmpty || sites.isEmpty
                  ? null
                  : () {
                      app.createShift(
                        employeeId: people[who].id,
                        weekdayIndex: day,
                        timeLabel: _times[_time],
                        siteId: sites[site].id,
                      );
                      Navigator.of(context).pop();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
