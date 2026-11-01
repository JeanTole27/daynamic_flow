import '../state/models.dart';

/// Datos de los reportes, calculados a partir de los fichajes reales.
/// La exportación (CSV/PDF) se arma en el teléfono con estos datos.
abstract class ReportsService {
  /// employeeId -> horas en el periodo.
  Future<Map<String, double>> fetchHours(DateTime from, DateTime to);

  /// Fichajes que se cruzan con [from, to), con su número de fotos. El
  /// gerente ve los de toda su organización.
  Future<List<ReportEntry>> fetchEntries(DateTime from, DateTime to);
}
