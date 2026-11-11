/// Configuración que llega al compilar con
/// `flutter run --dart-define-from-file=env.json` (ver README).
class AppConfig {
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-flash-latest');

  static bool get hasGemini => geminiApiKey.isNotEmpty;
}
