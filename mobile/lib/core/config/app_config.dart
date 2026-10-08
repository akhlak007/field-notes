import 'dart:io';

/// Single place the app reads `--dart-define=API_BASE_URL=...`.
///
/// Release APKs must pass a public HTTPS URL. If the define is omitted,
/// Android uses the emulator loopback (`10.0.2.2`); desktop uses localhost
/// so `flutter run` still reaches a local API (original task brief).
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  static String apiBaseUrl() {
    final raw = apiBaseUrlDefine.isNotEmpty
        ? apiBaseUrlDefine
        : (Platform.isAndroid
              ? 'http://10.0.2.2:8080'
              : 'http://localhost:8080');
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
