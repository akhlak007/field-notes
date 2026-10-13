import 'dart:io';

import 'package:flutter/foundation.dart';

/// Single place the app picks the API host.
///
/// Release APKs talk to the public HTTPS backend so a phone or reviewer
/// does not need `--dart-define`. Debug `flutter run` still uses localhost
/// (or the Android emulator loopback) unless a define is passed.
class AppConfig {
  const AppConfig._();

  static const String productionApiUrl = 'https://field-notes-api.onrender.com';

  static const String apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

  static String apiBaseUrl() {
    final raw = apiBaseUrlDefine.isNotEmpty
        ? apiBaseUrlDefine
        : (kReleaseMode
              ? productionApiUrl
              : (Platform.isAndroid
                    ? 'http://10.0.2.2:8080'
                    : 'http://localhost:8080'));
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
}
