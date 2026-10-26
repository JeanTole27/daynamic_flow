/// Configuración inyectada al compilar, nunca escrita en el código:
///
///   flutter run --dart-define-from-file=env.json
///
/// (ver `env.example.json`). Solo va aquí la clave *publishable/anon* de
/// Supabase, que es pública por diseño: la seguridad real la ponen las
/// políticas RLS de `supabase/migrations`. La `service_role` jamás debe
/// estar en la app — solo en Edge Functions.
///
/// Sin estas variables la app arranca en modo demo, con datos en memoria.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
