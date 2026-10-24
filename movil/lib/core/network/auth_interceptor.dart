import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

typedef OnSessionExpiredCallback = void Function();

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storageService;
  final Dio _dio;
  final OnSessionExpiredCallback? onSessionExpired;

  AuthInterceptor({
    required SecureStorageService storageService,
    required Dio dio,
    this.onSessionExpired,
  })  : _storageService = storageService,
        _dio = dio;

  bool _isPublicEndpoint(String path) {
    return path.contains(AppConstants.endpointLogin) ||
        path.contains(AppConstants.endpointRefresh) ||
        path.contains('/auth/recuperar/');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicEndpoint(options.path)) {
      final token = await _storageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Check if error is 401 and not on login/refresh itself
    if (statusCode == 401 && !_isPublicEndpoint(path)) {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // Use a fresh Dio instance to avoid interceptor recursion
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: err.requestOptions.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          final refreshResponse = await refreshDio.post(
            AppConstants.endpointRefresh,
            data: {'refresh': refreshToken},
          );

          if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
            final newAccessToken = refreshResponse.data['access'] as String?;
            final newRefreshToken = refreshResponse.data['refresh'] as String? ?? refreshToken;

            if (newAccessToken != null) {
              await _storageService.saveTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
              );

              // Retry the original failed request
              final options = err.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await _dio.fetch(options);
              return handler.resolve(retryResponse);
            }
          }
        } catch (refreshErr) {
          // Refresh failed - tokens invalid or remote logout occurred
          await _storageService.clearAll();
          onSessionExpired?.call();
          return handler.next(err);
        }
      } else {
        await _storageService.clearAll();
        onSessionExpired?.call();
      }
    }

    handler.next(err);
  }
}
