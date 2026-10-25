/// CONEXIÓN PENDIENTE — no implementada a propósito.
///
/// Reemplaza `AppState.exportCsv`/`exportPdf`. Necesita calcular horas y
/// costo desde los fichajes reales del servidor (no desde `Employee.hoursWorked`
/// mock) y generar/enviar el archivo — probablemente un endpoint que arma
/// el CSV/PDF server-side y lo manda por correo, en vez de generarlo en el
/// cliente.
abstract class ReportsService {
  Future<void> exportCsv({required DateTime from, required DateTime to});

  Future<void> exportPdf({required DateTime from, required DateTime to});
}
