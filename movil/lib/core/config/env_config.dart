import 'package:flutter/foundation.dart';

class EnvConfig {
  EnvConfig._();

  /// URL del backend en producción (Render)
  static const String _productionUrl = 'https://ceos-qb08.onrender.com/api';

  /// URLs para desarrollo local
  static const String _defaultAndroidUrl = 'http://10.0.2.2:8000/api';
  static const String _defaultLocalUrl = 'http://localhost:8000/api';

  static String get apiBaseUrl {
    // 1. Permite sobreescribir en compilación: --dart-define=API_URL=...
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    // 2. En modo Release (compilación para producción/APK) usa automáticamente la nube
    if (kReleaseMode) {
      return _productionUrl;
    }

    // 3. En desarrollo (Debug):
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _defaultAndroidUrl;
    }
    return _defaultLocalUrl;
  }

  // 25 segundos para contemplar latencia móvil y cold starts
  static const Duration connectTimeout = Duration(seconds: 25);
  static const Duration receiveTimeout = Duration(seconds: 25);
}
