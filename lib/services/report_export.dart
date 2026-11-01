import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../i18n/app_lang.dart';
import '../i18n/app_strings.dart';
import '../i18n/formatters.dart';
import '../state/models.dart';

/// Lo que necesita un archivo de reporte. Se arma en el teléfono a partir
/// de los fichajes del periodo; no depende de Flutter ni del backend.
class ReportExportData {
  const ReportExportData({
    required this.orgName,
    required this.from,
    required this.to,
    required this.periodLabel,
    required this.generatedAt,
    required this.rows,
    required this.siteName,
    required this.lang,
  });

  final String orgName;

  /// [from, to) del periodo.
  final DateTime from;
  final DateTime to;
  final String periodLabel;
  final DateTime generatedAt;
  final List<ReportRow> rows;
  final String Function(String siteId) siteName;
  final AppLang lang;

  AppStrings get t => AppStrings.of(lang);

  /// "reporte-horas_2026-09-01_2026-09-15"
  String get fileBaseName {
    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final last = to.subtract(const Duration(days: 1));
    return '${t['reportFile']}_${d(from)}_${d(last)}';
  }

  double hoursOf(ReportEntry e) =>
      e.workedWithin(from, to, generatedAt).inMinutes / 60;
}

/// CSV con un fichaje por fila. En español usa `;` y coma decimal, como
/// espera Excel configurado para Colombia; en inglés, `,` y punto.
String buildReportCsv(ReportExportData data) {
  final t = data.t;
  final es = data.lang == AppLang.es;
  final sep = es ? ';' : ',';

  String cell(Object? v) {
    final s = '${v ?? ''}';
    final needsQuotes =
        s.contains(sep) || s.contains('"') || s.contains('\n');
    return needsQuotes ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String num2(double v) {
    final s = v.toStringAsFixed(2);
    return es ? s.replaceAll('.', ',') : s;
  }

  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final lines = <String>[
    [
      t['csvEmployee'],
      t['csvPosition'],
      t['csvDate'],
      t['site'],
      t['csvIn'],
      t['csvOut'],
      t['csvHours'],
      t['csvRate'],
      t['csvCost'],
      t['csvPhotos'],
      t['csvOutside'],
    ].map(cell).join(sep),
  ];
  for (final row in data.rows) {
    final emp = row.employee;
    for (final e in row.entries.reversed) {
      final hours = data.hoursOf(e);
      final out = e.clockOutAt;
      lines.add(
        [
          emp.name,
          emp.roleFor(data.lang == AppLang.en),
          date(e.clockInAt),
          data.siteName(e.siteId),
          Fmt.time(e.clockInAt),
          out == null ? t['inProgress'] : Fmt.time(out),
          num2(hours),
          emp.hourlyRate.round(),
          (hours * emp.hourlyRate).round(),
          e.photoCount,
          e.clockOutOutside ? t['yes'] : t['no'],
        ].map(cell).join(sep),
      );
    }
  }
  // BOM: Excel en Windows reconoce así las tildes y la ñ.
  return '﻿${lines.join('\r\n')}\r\n';
}

/// La fuente estándar del PDF solo trae caracteres latinos básicos: los
/// guiones, comillas y puntos suspensivos tipográficos se cambian por sus
/// equivalentes y cualquier otro carácter (p. ej. emojis en un nombre) por
/// "?", para que no salgan cuadros vacíos.
String pdfSafe(String s) {
  const map = {
    '–': '-', '—': '-', '…': '...',
    '‘': "'", '’': "'", '“': '"', '”': '"',
    ' ': ' ', ' ': ' ',
  };
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    out.write(map[ch] ?? (rune <= 0xFF ? ch : '?'));
  }
  return out.toString();
}

/// PDF: resumen por persona con el total, y después cada fichaje.
Future<Uint8List> buildReportPdf(ReportExportData data) {
  final t = data.t;
  final en = data.lang == AppLang.en;
  const green = PdfColor.fromInt(0xFF029A45);
  const muted = PdfColor.fromInt(0xFF5B6A61);
  const line = PdfColor.fromInt(0xFFDCE5DF);
  const soft = PdfColor.fromInt(0xFFE6F6EC);

  String money(double v) => Fmt.money(v, data.lang);
  String hours(double v) {
    final m = (v * 60).round();
    return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }

  final totalHours = data.rows.fold<double>(0, (a, r) => a + r.hours);
  final totalCost = data.rows.fold<double>(0, (a, r) => a + r.cost);
  final totalEntries = data.rows.fold<int>(0, (a, r) => a + r.entries.length);

  final headerStyle = pw.TextStyle(
    fontSize: 8.5,
    fontWeight: pw.FontWeight.bold,
    color: muted,
  );
  const cellStyle = pw.TextStyle(fontSize: 9);

  pw.Widget table({
    required List<String> headers,
    required List<List<String>> rows,
    required Map<int, pw.Alignment> align,
    required Map<int, pw.TableColumnWidth> widths,
    List<String>? footer,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers.map(pdfSafe).toList(),
      data: [
        for (final r in [...rows, ?footer]) r.map(pdfSafe).toList(),
      ],
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: const pw.BoxDecoration(color: soft),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: line, width: .5)),
      ),
      border: null,
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellAlignments: align,
      headerAlignments: align,
      columnWidths: widths,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    );
  }

  final doc = pw.Document(title: '${t['reports']} · ${data.orgName}');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            pdfSafe('${data.orgName} · ${data.periodLabel}'),
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          pdfSafe(data.orgName.toUpperCase()),
          style: pw.TextStyle(
            fontSize: 9,
            color: green,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          t['hoursReport'],
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          pdfSafe(
            '${data.periodLabel} · ${t['generatedOn']} '
            '${Fmt.longDate(data.generatedAt, data.lang)} ${Fmt.time(data.generatedAt)}',
          ),
          style: const pw.TextStyle(fontSize: 9.5, color: muted),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: green,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              for (final (label, value) in [
                (t['totalHours'], hours(totalHours)),
                (t['estCost'], money(totalCost)),
                (t['clockIns'], '$totalEntries'),
              ])
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        label.toUpperCase(),
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        value,
                        style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          t['summaryByPerson'],
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        table(
          headers: [
            t['csvEmployee'],
            t['csvPosition'],
            t['clockIns'],
            t['csvHours'],
            t['csvRate'],
            t['csvCost'],
          ],
          rows: [
            for (final r in data.rows)
              [
                r.overtime ? '${r.employee.name} *' : r.employee.name,
                r.employee.roleFor(en),
                '${r.entries.length}',
                hours(r.hours),
                money(r.employee.hourlyRate),
                money(r.cost),
              ],
          ],
          footer: [
            t['total'],
            '',
            '$totalEntries',
            hours(totalHours),
            '',
            money(totalCost),
          ],
          align: {
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
            5: pw.Alignment.centerRight,
          },
          widths: {
            0: const pw.FlexColumnWidth(2.4),
            1: const pw.FlexColumnWidth(1.6),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1.4),
          },
        ),
        if (data.rows.any((r) => r.overtime)) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            '* ${t['overtimeNote']}',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Text(
          t['clockInDetail'],
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (totalEntries == 0)
          pw.Text(
            t['noClockIns'],
            style: const pw.TextStyle(fontSize: 9.5, color: muted),
          )
        else
          table(
            headers: [
              t['csvDate'],
              t['csvEmployee'],
              t['site'],
              t['csvIn'],
              t['csvOut'],
              t['csvHours'],
              t['notes'],
            ],
            rows: [
              for (final e in [
                for (final r in data.rows)
                  for (final e in r.entries) (r.employee, e),
              ]..sort((a, b) => a.$2.clockInAt.compareTo(b.$2.clockInAt)))
                [
                  Fmt.shortDate(e.$2.clockInAt, data.lang),
                  e.$1.name,
                  data.siteName(e.$2.siteId),
                  Fmt.time(e.$2.clockInAt),
                  e.$2.clockOutAt == null
                      ? t['inProgress']
                      : Fmt.time(e.$2.clockOutAt!),
                  hours(data.hoursOf(e.$2)),
                  [
                    if (e.$2.clockOutOutside) t['outsideShort'],
                    if (e.$2.photoCount > 0)
                      t.fmt('photosCount', {'n': e.$2.photoCount}),
                  ].join(' · '),
                ],
            ],
            align: {
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
            },
            widths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(.9),
              4: const pw.FlexColumnWidth(.9),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1.7),
            },
          ),
      ],
    ),
  );
  return doc.save();
}
