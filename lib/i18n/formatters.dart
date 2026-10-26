import 'app_lang.dart';

/// Formato de fechas, horas y dinero sin depender de `intl`.
class Fmt {
  const Fmt._();

  static const _monthsEs = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  static const _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdaysEs = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  static const _weekdaysEn = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "09:00"
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// "09:00–17:00"
  static String timeRange(DateTime a, DateTime b) => '${time(a)}–${time(b)}';

  /// "09–17" (compacto, para el calendario semanal)
  static String hourRange(DateTime a, DateTime b) {
    String h(DateTime d) =>
        d.minute == 0 ? _two(d.hour) : '${_two(d.hour)}:${_two(d.minute)}';
    return '${h(a)}–${h(b)}';
  }

  /// "Lunes 7 de septiembre" / "Monday, September 7"
  static String longDate(DateTime d, AppLang lang) => switch (lang) {
    AppLang.es => '${_weekdaysEs[d.weekday - 1]} ${d.day} de ${_monthsEs[d.month - 1]}',
    AppLang.en => '${_weekdaysEn[d.weekday - 1]}, ${_monthsEn[d.month - 1]} ${d.day}',
  };

  static String _shortMonth(int month, AppLang lang) => switch (lang) {
    AppLang.es => _monthsEs[month - 1].substring(0, 3),
    AppLang.en => _monthsEn[month - 1].substring(0, 3),
  };

  /// "1 – 7 sept" (rango inclusivo de días)
  static String dayRange(DateTime from, DateTime toInclusive, AppLang lang) {
    final sameMonth = from.month == toInclusive.month;
    final left = sameMonth ? '${from.day}' : '${from.day} ${_shortMonth(from.month, lang)}';
    return '$left – ${toInclusive.day} ${_shortMonth(toInclusive.month, lang)}';
  }

  /// "1–15 oct 2026"
  static String periodRange(DateTime from, DateTime toInclusive, AppLang lang) =>
      '${from.day}–${toInclusive.day} ${_shortMonth(toInclusive.month, lang)} '
      '${toInclusive.year}';

  /// "$6.500" (es) / "$6,500" (en)
  static String money(double amount, AppLang lang) {
    final rounded = amount.round().abs().toString();
    final sep = lang == AppLang.es ? '.' : ',';
    final buf = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      if (i > 0 && (rounded.length - i) % 3 == 0) buf.write(sep);
      buf.write(rounded[i]);
    }
    return '${amount < 0 ? '-' : ''}\$$buf';
  }

  /// "$2.03M" / "$12.5K" — para totales grandes.
  static String moneyCompact(double amount) {
    if (amount.abs() >= 1e6) return '\$${(amount / 1e6).toStringAsFixed(2)}M';
    if (amount.abs() >= 1e3) return '\$${(amount / 1e3).toStringAsFixed(1)}K';
    return '\$${amount.round()}';
  }

  /// "4h 12m"
  static String duration(Duration d) =>
      '${d.inHours}h ${_two(d.inMinutes % 60)}m';
}
