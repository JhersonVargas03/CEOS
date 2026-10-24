import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin_models.dart';
import '../models/inventario_models.dart';

class NotificacionesRepository {
  final ApiClient _apiClient;

  NotificacionesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<NotificacionModel>> obtenerNotificaciones() async {
    try {
      final response = await _apiClient.get(AppConstants.endpointNotificaciones);
      if (response.data is List) {
        return (response.data as List)
            .map((e) => NotificacionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> marcarLeida(int notificacionId) async {
    await _apiClient.post(
      '${AppConstants.endpointNotificaciones}/$notificacionId/marcar-leida/',
      data: {},
    );
  }

  Future<void> marcarTodasLeidas() async {
    await _apiClient.post(
      '${AppConstants.endpointNotificaciones}/marcar-todas-leidas/',
      data: {},
    );
  }

  Future<List<MovimientoHistorialModel>> obtenerHistorialUsuario(int userId) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.endpointHistorialUsuario}/$userId/historial',
      );
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MovimientoHistorialModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
