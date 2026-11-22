/// Values injected at build time from the project-root `.env` file:
///
///   flutter run --dart-define-from-file=.env
///
/// See `.env.example` for the list of keys. Missing keys are empty strings.
class Env {
  Env._();

  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const googleTranslateApiKey = String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY');
  static const googleDirectionsApiKey = String.fromEnvironment('GOOGLE_DIRECTIONS_API_KEY');

  /// Supabase project URL and publishable (anon) key. Safe to ship in the app:
  /// Row Level Security protects the data. Never put the service_role key here.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Base URL of the Node API (Railway), e.g. https://api.zing.ipynb.site
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
