import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin_models.dart';
import '../models/usuario_model.dart';

class AdminRepository {
  final ApiClient _apiClient;

  AdminRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  // --- Usuarios ---
  Future<List<UsuarioModel>> obtenerUsuarios({
    String? search,
    String? rol,
    bool? activo,
  }) async {
    final params = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (rol != null && rol.isNotEmpty) params['rol'] = rol;
    if (activo != null) params['activo'] = activo;

    final response = await _apiClient.get(
      AppConstants.endpointAdminUsuarios,
      queryParameters: params.isNotEmpty ? params : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UsuarioModel> obtenerDetalleUsuario(int userId) async {
    final response = await _apiClient.get('${AppConstants.endpointAdminUsuarios}/$userId');
    return UsuarioModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> crearUsuario({
    required String username,
    required String correoInterno,
    String? telefono,
    List<int>? rolesIds,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointAdminUsuarios,
      data: {
        'username': username.trim().toLowerCase(),
        'correo_interno': correoInterno.trim().toLowerCase(),
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (rolesIds != null) 'roles_ids': rolesIds,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> actualizarEstadoUsuario(int userId, bool activo) async {
    await _apiClient.patch(
      '${AppConstants.endpointAdminUsuarios}/$userId/estado',
      data: {'activo': activo},
    );
  }

  Future<void> cerrarSesionRemota(int userId) async {
    await _apiClient.post(
      '${AppConstants.endpointAdminUsuarios}/$userId/cerrar-sesion',
    );
  }

  Future<void> actualizarRolesUsuario(int userId, List<int> rolesIds) async {
    await _apiClient.patch(
      '${AppConstants.endpointAdminUsuarios}/$userId/roles',
      data: {'roles_ids': rolesIds},
    );
  }

  // --- Roles & Permisos ---
  Future<List<RolModel>> obtenerRoles() async {
    final response = await _apiClient.get(AppConstants.endpointAdminRoles);
    final list = response.data as List<dynamic>;
    return list.map((e) => RolModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PermisoModel>> obtenerPermisos() async {
    final response = await _apiClient.get(AppConstants.endpointAdminPermisos);
    final list = response.data as List<dynamic>;
    return list.map((e) => PermisoModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RolModel> crearRol({
    required String nombre,
    String descripcion = '',
    List<int>? permisosIds,
    List<String>? permisosCodigos,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointAdminRoles,
      data: {
        'nombre': nombre,
        'descripcion': descripcion,
        if (permisosIds != null) 'permisos_ids': permisosIds,
        if (permisosCodigos != null) 'permisos_codigos': permisosCodigos,
      },
    );
    return RolModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RolModel> actualizarRol({
    required int rolId,
    String? nombre,
    String? descripcion,
    List<int>? permisosIds,
    List<String>? permisosCodigos,
  }) async {
    final response = await _apiClient.put(
      '${AppConstants.endpointAdminRoles}/$rolId',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        if (permisosIds != null) 'permisos_ids': permisosIds,
        if (permisosCodigos != null) 'permisos_codigos': permisosCodigos,
      },
    );
    return RolModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> eliminarRol(int rolId) async {
    await _apiClient.delete('${AppConstants.endpointAdminRoles}/$rolId');
  }

  // --- Auditoría Global ---
  Future<Map<String, dynamic>> obtenerAuditoria({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? accion,
    int? usuarioId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (accion != null && accion.trim().isNotEmpty) params['accion'] = accion.trim();
    if (usuarioId != null) params['usuario_id'] = usuarioId;

    final response = await _apiClient.get(
      AppConstants.endpointAdminAuditoria,
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  // --- Configuración del Sistema (Superadmin) ---
  Future<ConfiguracionSistemaModel> obtenerConfiguracionSistema() async {
    final response = await _apiClient.get(AppConstants.endpointAdminConfig);
    return ConfiguracionSistemaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> actualizarCanalMensajeria(String canal) async {
    await _apiClient.patch(
      AppConstants.endpointAdminConfigCanal,
      data: {'canal_mensajeria': canal},
    );
  }

  Future<void> actualizarAlertasInventario(bool activas) async {
    await _apiClient.patch(
      AppConstants.endpointAdminConfigAlertas,
      data: {'alertas_inventario_activas': activas},
    );
  }

  // --- Backups (Superadmin) ---
  Future<Map<String, dynamic>> generarBackupManual() async {
    final response = await _apiClient.post(AppConstants.endpointBackupGenerar);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> obtenerEstadoBackup(String tareaId) async {
    final response = await _apiClient.get('${AppConstants.endpointBackupEstado}/$tareaId');
    return response.data as Map<String, dynamic>;
  }

  Future<List<BackupHistorialModel>> obtenerHistorialBackups() async {
    final response = await _apiClient.get(AppConstants.endpointBackupHistorial);
    List<dynamic> list;
    if (response.data is List) {
      list = response.data as List<dynamic>;
    } else if (response.data is Map) {
      final map = response.data as Map<String, dynamic>;
      list = (map['resultados'] ?? map['backups'] ?? []) as List<dynamic>;
    } else {
      list = [];
    }
    return list.map((e) => BackupHistorialModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
