import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int? sessionVersion,
  }) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
    if (sessionVersion != null) {
      await _storage.write(
        key: AppConstants.keySessionVersion,
        value: sessionVersion.toString(),
      );
    }
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.keyRefreshToken);
  }

  Future<int?> getSessionVersion() async {
    final val = await _storage.read(key: AppConstants.keySessionVersion);
    if (val != null) {
      return int.tryParse(val);
    }
    return null;
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(
      key: AppConstants.keyUserData,
      value: jsonEncode(userData),
    );
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final raw = await _storage.read(key: AppConstants.keyUserData);
    if (raw != null && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> setPrimerLoginPendiente(bool pendiente) async {
    await _storage.write(
      key: AppConstants.keyPrimerLoginPendiente,
      value: pendiente ? 'true' : 'false',
    );
  }

  Future<bool> isPrimerLoginPendiente() async {
    final val = await _storage.read(key: AppConstants.keyPrimerLoginPendiente);
    return val == 'true';
  }

  Future<void> setThemeMode(String mode) async {
    await _storage.write(key: 'ceos_theme_mode', value: mode);
  }

  Future<String?> getThemeMode() async {
    return await _storage.read(key: 'ceos_theme_mode');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
