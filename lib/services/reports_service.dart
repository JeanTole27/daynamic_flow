/// Horas trabajadas por empleado, calculadas en el servidor a partir de los
/// fichajes reales.
///
/// PENDIENTE: exportar CSV/PDF. Lo recomendable es una Edge Function que
/// arme el archivo y lo envíe por correo, en vez de generarlo en el cliente.
abstract class ReportsService {
  /// employeeId -> horas en el periodo.
  Future<Map<String, double>> fetchHours(DateTime from, DateTime to);
}
