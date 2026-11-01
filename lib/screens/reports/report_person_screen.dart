import 'package:flutter/material.dart';

import '../../i18n/formatters.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';

/// Detalle de una persona en el periodo del reporte: totales y cada
/// fichaje con su sitio, horas, fotos y si salió fuera del sitio.
class ReportPersonScreen extends StatelessWidget {
  const ReportPersonScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final row = app.reportRowFor(employeeId);
    final emp = row?.employee ?? app.employeeById(employeeId);
    final (from, to) = app.reportRange;
    final now = app.now;

    // Agrupados por día, del más reciente al más antiguo.
    final byDay = <DateTime, List<ReportEntry>>{};
    for (final e in row?.entries ?? const <ReportEntry>[]) {
      byDay.putIfAbsent(DateUtils.dateOnly(e.clockInAt), () => []).add(e);
    }

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
                  size: 52,
                  fontSize: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: AppTextStyles.sans(
                          size: 22,
                          weight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        [
                          emp.roleFor(app.isEnglish),
                          t.fmt('ofCostRate', {'rate': app.rateLabel(emp)}),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: AppTextStyles.body(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              app.reportPeriodLabel,
              style: AppTextStyles.mono(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(
                  value: AppState.hoursLabel(row?.hours ?? 0),
                  label: t['csvHours'],
                  highlight: row?.overtime ?? false,
                ),
                const SizedBox(width: 8),
                _Stat(
                  value: Fmt.money(row?.cost ?? 0, app.lang),
                  label: t['estCost'],
                ),
                const SizedBox(width: 8),
                _Stat(
                  value: '${row?.entries.length ?? 0}',
                  label: t['clockIns'],
                ),
              ],
            ),
            if (row != null && row.overtime) ...[
              const SizedBox(height: 8),
              Text(
                t['overtimeNote'],
                style: AppTextStyles.sans(size: 12.5, color: AppColors.amber),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              t['clockInDetail'].toUpperCase(),
              style: AppTextStyles.eyebrow(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            if (byDay.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Text(t['personNoClockIns'], style: AppTextStyles.body()),
              ),
            for (final MapEntry(key: day, value: entries) in byDay.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  Fmt.longDate(day, app.lang),
                  style: AppTextStyles.sans(size: 13, weight: FontWeight.w700),
                ),
              ),
              for (final e in entries) ...[
                _EntryCard(
                  site: app.siteById(e.siteId)?.name ?? '—',
                  range: e.isOpen
                      ? '${Fmt.time(e.clockInAt)}–…'
                      : Fmt.timeRange(e.clockInAt, e.clockOutAt!),
                  worked: AppState.hoursLabel(
                    e.workedWithin(from, to, now).inMinutes / 60,
                  ),
                  tags: [
                    if (e.isOpen) (t['inProgress'], AppColors.primaryText),
                    if (e.clockOutOutside) (t['outsideShort'], AppColors.amber),
                    if (e.photoCount > 0)
                      (
                        t.fmt('photosCount', {'n': e.photoCount}),
                        AppColors.muted,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.mono(
                  size: 17,
                  weight: FontWeight.w700,
                  color: highlight ? AppColors.amber : AppColors.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.sans(size: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.site,
    required this.range,
    required this.worked,
    required this.tags,
  });

  final String site;
  final String range;
  final String worked;
  final List<(String, Color)> tags;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                range,
                style: AppTextStyles.mono(size: 14, weight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  site,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sans(size: 13, color: AppColors.muted),
                ),
              ),
              Text(
                worked,
                style: AppTextStyles.mono(size: 13, weight: FontWeight.w600),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (label, color) in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: AppTextStyles.sans(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
