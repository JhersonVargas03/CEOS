class EnvConfig {
  EnvConfig._();

  /// Default API base URL.
  /// 10.0.2.2 is used for Android emulator to access host localhost:8000
  /// For Linux/Web/iOS, localhost:8000 is used.
  static const String _defaultAndroidUrl = 'http://10.0.2.2:8000/api';
  static const String _defaultLocalUrl = 'http://localhost:8000/api';

  static String get apiBaseUrl {
    // Allows overriding via compile-time environment variable: --dart-define=API_URL=...
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }
    return _defaultLocalUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
