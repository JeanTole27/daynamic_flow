import 'dart:ui';

enum AppLang {
  es,
  en;

  String get label => switch (this) {
    AppLang.es => 'Español',
    AppLang.en => 'English',
  };

  /// Idioma de los componentes de Flutter (reloj, calendario, botones de
  /// los diálogos del sistema).
  Locale get locale => Locale(name);

  /// El guardado, o el del teléfono si nunca se eligió (español salvo que
  /// el teléfono esté en inglés).
  static AppLang resolve(String? saved, Locale device) {
    for (final lang in values) {
      if (lang.name == saved) return lang;
    }
    return device.languageCode == 'en' ? AppLang.en : AppLang.es;
  }
}
