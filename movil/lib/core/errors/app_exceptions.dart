import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final dynamic rawData;

  const AppException({
    required this.message,
    this.statusCode,
    this.code,
    this.rawData,
  });

  @override
  String toString() => message;

  factory AppException.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          message: 'Tiempo de espera agotado. Por favor, intenta de nuevo.',
          code: 'TIMEOUT',
        );

      case DioExceptionType.connectionError:
        return const AppException(
          message: 'No se pudo conectar con el servidor de la clínica. Verifica tu conexión a red.',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badResponse:
        final response = dioError.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        return AppException.fromBackendResponse(statusCode, data);

      case DioExceptionType.cancel:
        return const AppException(
          message: 'La solicitud fue cancelada.',
          code: 'CANCELLED',
        );

      default:
        return AppException(
          message: dioError.message ?? 'Ocurrió un error inesperado de comunicación.',
          code: 'UNKNOWN',
        );
    }
  }

  factory AppException.fromBackendResponse(int? statusCode, dynamic data) {
    String message = 'Ocurrió un error inesperado en el servidor.';
    String? code;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        message = data['error'].toString();
      } else if (data.containsKey('detail')) {
        message = data['detail'].toString();
      } else if (data.containsKey('mensaje')) {
        message = data['mensaje'].toString();
      } else if (data.containsKey('non_field_errors')) {
        final errs = data['non_field_errors'];
        if (errs is List && errs.isNotEmpty) {
          message = errs.first.toString();
        }
      } else {
        // Collect first field error if any
        for (final entry in data.entries) {
          if (entry.value is List && (entry.value as List).isNotEmpty) {
            message = '${entry.key}: ${(entry.value as List).first}';
            break;
          } else if (entry.value is String) {
            message = entry.value as String;
            break;
          }
        }
      }

      // Desempacar detalles de validación si existen (ej. serializer.errors en data['detalles'])
      if (data.containsKey('detalles')) {
        final detalles = data['detalles'];
        if (detalles is Map<String, dynamic>) {
          final parts = <String>[];
          detalles.forEach((key, val) {
            if (val is List && val.isNotEmpty) {
              parts.add('$key: ${val.join(", ")}');
            } else if (val is String && val.isNotEmpty) {
              parts.add('$key: $val');
            }
          });
          if (parts.isNotEmpty) {
            message = '$message: ${parts.join(" | ")}';
          }
        } else if (detalles is List && detalles.isNotEmpty) {
          message = '$message: ${detalles.join(", ")}';
        } else if (detalles is String && detalles.isNotEmpty) {
          message = '$message: $detalles';
        }
      }

      if (data.containsKey('codigo')) {
        code = data['codigo'].toString();
      } else if (data.containsKey('code')) {
        code = data['code'].toString();
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    // Specific status code overrides with human-friendly messages
    if (statusCode == 401) {
      if (message.toLowerCase().contains('bloquead')) {
        message = 'Tu cuenta está bloqueada temporalmente por 15 minutos debido a múltiples intentos fallidos.';
      } else if (message.toLowerCase().contains('credencial') || message.toLowerCase().contains('usuario')) {
        message = 'Usuario o contraseña incorrectos.';
      } else if (message.toLowerCase().contains('token') || message.toLowerCase().contains('sesion')) {
        message = 'Tu sesión ha expirado o fue cerrada desde otro dispositivo. Por favor ingresa nuevamente.';
      }
    } else if (statusCode == 403) {
      if (message.toLowerCase().contains('bloquead')) {
        message = 'Acceso bloqueado temporalmente. Por favor intenta más tarde.';
      } else if (message.toLowerCase().contains('primer') || message.toLowerCase().contains('cambiar')) {
        message = 'Debes completar el proceso de primer inicio de sesión obligatorio.';
      } else {
        message = 'No tienes los permisos requeridos para realizar esta acción.';
      }
    } else if (statusCode == 404) {
      if (!message.contains('encontrado')) {
        message = 'El registro solicitado no fue encontrado o fue eliminado.';
      }
    } else if (statusCode == 429) {
      message = 'Demasiadas solicitudes en poco tiempo. Por favor espera unos momentos antes de reintentar.';
    }

    return AppException(
      message: message,
      statusCode: statusCode,
      code: code,
      rawData: data,
    );
  }
}
