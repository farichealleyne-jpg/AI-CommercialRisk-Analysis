/// Third-party API keys, supplied at build time so they never enter the repo.
///
/// Build with them like this (see RUNNING.md):
///
///   flutter build web --release --no-web-resources-cdn \
///     --dart-define=MAPS_API_KEY=... --dart-define=GEMINI_API_KEY=...
///
/// A key left unset is not an error: callers check the matching `has` getter
/// and report the feature as unconfigured rather than failing mid-request.
/// The committed web bundle is built without keys, so nothing secret ships
/// in version control.
///
/// Note that a key the browser uses is visible to anyone using the app — that
/// is inherent to client-side calls, not something this file can prevent.
/// Restrict these keys by HTTP referrer in the Google Cloud console.
class ApiKeys {
  const ApiKeys._();

  static const String googleMaps = String.fromEnvironment('MAPS_API_KEY');
  static const String gemini = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGoogleMaps => googleMaps.isNotEmpty;
  static bool get hasGemini => gemini.isNotEmpty;
}
