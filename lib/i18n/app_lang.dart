enum AppLang {
  es,
  en;

  String get label => switch (this) {
    AppLang.es => 'Español',
    AppLang.en => 'English',
  };
}
