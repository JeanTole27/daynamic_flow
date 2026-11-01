import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:daynamic_flow/i18n/app_lang.dart';
import 'package:daynamic_flow/services/report_export.dart';
import 'package:daynamic_flow/state/app_state.dart';
import 'package:daynamic_flow/state/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPeriod.range', () {
    test('fortnights and months around a date', () {
      final early = DateTime(2026, 3, 7);
      final late = DateTime(2026, 3, 20);
      expect(ReportPeriod.currentFortnight.range(early),
          (DateTime(2026, 3, 1), DateTime(2026, 3, 16)));
      expect(ReportPeriod.previousFortnight.range(early),
          (DateTime(2026, 2, 16), DateTime(2026, 3, 1)));
      expect(ReportPeriod.currentFortnight.range(late),
          (DateTime(2026, 3, 16), DateTime(2026, 4, 1)));
      expect(ReportPeriod.previousFortnight.range(late),
          (DateTime(2026, 3, 1), DateTime(2026, 3, 16)));
      expect(ReportPeriod.previousMonth.range(DateTime(2026, 1, 10)),
          (DateTime(2025, 12, 1), DateTime(2026, 1, 1)));
    });
  });

  group('ReportEntry.workedWithin', () {
    final from = DateTime(2026, 3, 1);
    final to = DateTime(2026, 3, 16);

    test('counts only the part inside the period', () {
      final crossing = ReportEntry(
        id: 'a',
        employeeId: 'e',
        siteId: 's',
        clockInAt: DateTime(2026, 2, 28, 22),
        clockOutAt: DateTime(2026, 3, 1, 6),
      );
      expect(crossing.workedWithin(from, to, to), const Duration(hours: 6));
    });

    test('an open entry counts until now', () {
      final open = ReportEntry(
        id: 'b',
        employeeId: 'e',
        siteId: 's',
        clockInAt: DateTime(2026, 3, 5, 8),
      );
      expect(
        open.workedWithin(from, to, DateTime(2026, 3, 5, 10, 30)),
        const Duration(hours: 2, minutes: 30),
      );
    });
  });

  group('AppState reports (demo)', () {
    test('current fortnight adds up to the demo hours', () async {
      final app = AppState();
      await app.loadReport();
      final rows = app.reportRows;

      // Sin gerentes y sin inactivos que no ficharon.
      expect(rows.every((r) => r.employee.role == UserRole.employee), isTrue);
      final ana = rows.firstWhere((r) => r.employee.name == 'Ana Torres');
      expect(ana.hours, closeTo(62.5, 0.2));
      final diego = rows.firstWhere((r) => r.employee.name == 'Diego Sáenz');
      expect(diego.overtime, isTrue);
      expect(app.reportTotalCost, greaterThan(0));
    });

    test('changing the period reloads its clock-ins', () async {
      final app = AppState();
      await app.loadReport();
      final current = app.reportTotalHours;

      await app.setReportPeriod(ReportPeriod.previousFortnight);
      final previous = app.reportTotalHours;
      expect(previous, isNot(closeTo(current, 0.01)));
      expect(previous, greaterThan(0));

      // El demo solo tiene datos del 16 de agosto en adelante: el mes
      // anterior completo suma lo mismo que su segunda quincena.
      await app.setReportPeriod(ReportPeriod.previousMonth);
      expect(app.reportTotalHours, closeTo(previous, 0.01));
    });
  });

  group('export', () {
    Future<ReportExportData> data(AppLang lang) async {
      final app = AppState(lang: lang);
      await app.loadReport();
      return app.reportExportData;
    }

    test('CSV in Spanish uses ; and decimal comma, with BOM', () async {
      final csv = buildReportCsv(await data(AppLang.es));
      expect(csv.startsWith('﻿'), isTrue);
      final lines = csv.substring(1).trim().split('\r\n');
      expect(lines.first, startsWith('Empleado;Cargo;Fecha;Sitio;Entrada'));
      final ana = lines.firstWhere((l) => l.startsWith('Ana Torres;'));
      final cols = ana.split(';');
      expect(cols, hasLength(11));
      expect(cols[6], contains(','));
      expect(lines.length - 1, (await data(AppLang.es)).rows
          .fold<int>(0, (a, r) => a + r.entries.length));
    });

    test('CSV in English uses , and decimal point', () async {
      final csv = buildReportCsv(await data(AppLang.en));
      final lines = csv.substring(1).trim().split('\r\n');
      expect(lines.first, startsWith('Employee,Position,Date,Site,In'));
      final cols = lines[1].split(',');
      expect(cols, hasLength(11));
      expect(cols[6], matches(RegExp(r'^\d+\.\d{2}$')));
    });

    test('PDF is a valid document', () async {
      final bytes = await buildReportPdf(await data(AppLang.es));
      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('pdfSafe keeps accents and replaces what the PDF font lacks', () {
      expect(pdfSafe('1–15 sep · Sofía Ñuñez'), '1-15 sep · Sofía Ñuñez');
      expect(pdfSafe('En curso… “ok”'), 'En curso... "ok"');
      expect(pdfSafe('Ana 🌟'), 'Ana ?');
    });

    test('file name carries the period dates', () async {
      final d = await data(AppLang.es);
      expect(d.fileBaseName, 'reporte-horas_2026-09-01_2026-09-15');
    });
  });
}
