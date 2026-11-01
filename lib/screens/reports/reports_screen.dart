import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/device/report_share.dart';
import '../../services/report_export.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import 'report_person_screen.dart';

/// Horas y costo por persona en el periodo elegido, con detalle por persona
/// y exportación a CSV o PDF.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// 'csv' o 'pdf' mientras se genera; null si no.
  String? _exporting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).loadReport();
    });
  }

  Future<void> _export(BuildContext buttonContext, {required bool pdf}) async {
    final app = AppScope.of(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _exporting = pdf ? 'pdf' : 'csv');
    final data = app.reportExportData;
    try {
      final bytes = pdf
          ? await buildReportPdf(data)
          : utf8.encode(buildReportCsv(data));
      await shareReportFile(
        bytes: bytes,
        fileName: '${data.fileBaseName}.${pdf ? 'pdf' : 'csv'}',
        mimeType: pdf ? 'application/pdf' : 'text/csv',
        subject: app.strings.fmt('exportShareSubject', {
          'period': data.periodLabel,
        }),
        origin: origin,
      );
    } catch (_) {
      app.flash(app.strings.error('export_failed'));
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final rows = app.reportRows;
    // Escala de las barras: la persona con más horas, o el umbral de horas
    // extra si nadie llega.
    final maxHours = [
      app.reportPeriod.overtimeHours,
      for (final r in rows) r.hours,
    ].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Text(
              t['reports'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in ReportPeriod.values)
                  SelectableChip(
                    label: t[_periodKey(p)],
                    selected: app.reportPeriod == p,
                    onTap: () => app.setReportPeriod(p),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              app.reportPeriodLabel,
              style: AppTextStyles.mono(size: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              hours: app.totalHoursLabel,
              cost: app.estimatedCostLabel,
              clockIns: rows.fold(0, (a, r) => a + r.entries.length),
              loading: app.reportLoading,
            ),
            const SizedBox(height: 16),
            if (app.reportLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                t['tapForDetail'],
                style: AppTextStyles.sans(size: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              for (final r in rows) ...[
                _EmployeeBar(
                  row: r,
                  fraction: maxHours == 0 ? 0 : r.hours / maxHours,
                  overtimeLabel: t['overtime'],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReportPersonScreen(employeeId: r.employee.id),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (b) => PrimaryButton(
                      label: _exporting == 'csv' ? t['exporting'] : 'CSV',
                      onPressed: _exporting != null || app.reportLoading
                          ? null
                          : () => _export(b, pdf: false),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Builder(
                    builder: (b) => SecondaryButton(
                      label: _exporting == 'pdf' ? t['exporting'] : 'PDF',
                      onPressed: _exporting != null || app.reportLoading
                          ? null
                          : () => _export(b, pdf: true),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _periodKey(ReportPeriod p) => switch (p) {
    ReportPeriod.currentFortnight => 'periodCurrentFortnight',
    ReportPeriod.previousFortnight => 'periodPreviousFortnight',
    ReportPeriod.currentMonth => 'periodCurrentMonth',
    ReportPeriod.previousMonth => 'periodPreviousMonth',
  };
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.hours,
    required this.cost,
    required this.clockIns,
    required this.loading,
  });

  final String hours;
  final String cost;
  final int clockIns;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = AppScope.of(context).strings;
    final faded = AppColors.onPrimary.withValues(alpha: 0.62);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['totalHours'].toUpperCase(),
                style: AppTextStyles.eyebrow(color: faded),
              ),
              const SizedBox(height: 5),
              Text(
                loading ? '—' : hours,
                style: AppTextStyles.mono(
                  size: 34,
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                  letterSpacing: -1.2,
                ),
              ),
              Text(
                '${loading ? '—' : clockIns} ${t['clockIns'].toLowerCase()}',
                style: AppTextStyles.sans(size: 11.5, color: faded),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                loading ? '—' : cost,
                style: AppTextStyles.mono(
                  size: 17,
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t['estCost'],
                style: AppTextStyles.sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: faded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeBar extends StatelessWidget {
  const _EmployeeBar({
    required this.row,
    required this.fraction,
    required this.overtimeLabel,
    required this.onTap,
  });

  final ReportRow row;
  final double fraction;
  final String overtimeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.employee.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                if (row.overtime) ...[
                  Text(
                    overtimeLabel.toUpperCase(),
                    style: AppTextStyles.mono(
                      size: 9.5,
                      letterSpacing: 0.8,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  AppState.hoursLabel(row.hours),
                  style: AppTextStyles.mono(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.mutedDim,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.cardAlt,
                valueColor: AlwaysStoppedAnimation(
                  row.overtime ? AppColors.amber : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
