import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _storageService;

  AuthRepository({
    required ApiClient apiClient,
    required SecureStorageService storageService,
  })  : _apiClient = apiClient,
        _storageService = storageService;

  /// Iniciar sesión con identificador (username/correo) y password
  Future<UsuarioModel> login({
    required String identificador,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointLogin,
      data: {
        'identificador': identificador.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;
    // Backend returns: {"tokens": {"access": "...", "refresh": "..."}, "usuario": {...}}
    final tokens = data['tokens'] as Map<String, dynamic>? ?? data;
    final accessToken = tokens['access'] as String? ?? tokens['access_token'] as String;
    final refreshToken = tokens['refresh'] as String? ?? tokens['refresh_token'] as String;
    final sessionVersion = (data['usuario'] as Map<String, dynamic>?)?['session_version'] as int? ?? 1;

    await _storageService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionVersion: sessionVersion,
    );

    // Fetch user profile
    return await obtenerPerfil();
  }

  /// Obtener perfil del usuario actual desde /auth/me
  Future<UsuarioModel> obtenerPerfil() async {
    final response = await _apiClient.get(AppConstants.endpointMe);
    final data = response.data as Map<String, dynamic>;
    // /auth/me returns: {"usuario": {..., "roles": [...], "permisos": [...]}, "permisos_efectivos": [...]}
    final usuarioData = data['usuario'] as Map<String, dynamic>? ?? data;
    final permisosEfectivos = (data['permisos_efectivos'] as List<dynamic>?)?.map((e) => e.toString()).toList();
    // Merge permisos_efectivos into usuario data so UsuarioModel receives it as 'permisos'
    final merged = {
      ...usuarioData,
      if (permisosEfectivos != null) 'permisos': permisosEfectivos,
    };
    final usuario = UsuarioModel.fromJson(merged);
    await _storageService.saveUserData(merged);
    await _storageService.setPrimerLoginPendiente(!usuario.primerLoginCompletado);
    return usuario;
  }

  /// Primer Login - Paso 1: Cambiar contraseña inicial
  Future<void> primerLoginCambiarPassword({
    required String passwordNueva,
  }) async {
    await _apiClient.post(
      AppConstants.endpointPrimerLoginPassword,
      data: {'password_nueva': passwordNueva},
    );
  }

  /// Primer Login - Paso 2: Vincular Telegram
  Future<Map<String, dynamic>> primerLoginVincularTelegram() async {
    final response = await _apiClient.post(AppConstants.endpointPrimerLoginTelegram);
    return response.data as Map<String, dynamic>;
  }

  /// Primer Login - Paso 3a: Enviar OTP al teléfono
  Future<void> primerLoginEnviarOtpTelefono({
    required String telefono,
  }) async {
    await _apiClient.post(
      AppConstants.endpointPrimerLoginEnviarOtp,
      data: {'telefono': telefono},
    );
  }

  /// Primer Login - Paso 3b: Confirmar OTP de 6 dígitos
  Future<void> primerLoginConfirmarOtpTelefono({
    required String codigoOtp,
  }) async {
    await _apiClient.post(
      AppConstants.endpointPrimerLoginConfirmarOtp,
      data: {'codigo': codigoOtp},
    );
  }

  /// Primer Login - Finalizar flujo
  Future<UsuarioModel> primerLoginFinalizar() async {
    await _apiClient.post(AppConstants.endpointPrimerLoginFinalizar);
    await _storageService.setPrimerLoginPendiente(false);
    return await obtenerPerfil();
  }

  /// Telegram - Procesar updates manualmente (para desarrollo local sin webhook)
  Future<Map<String, dynamic>> telegramProcesarUpdates() async {
    try {
      final response = await _apiClient.post(
        AppConstants.endpointTelegramProcesarUpdates,
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return {'vinculados': 0, 'error': 'no se pudo procesar'};
    }
  }

  /// Recuperación de contraseña - Solicitar código
  Future<Map<String, dynamic>> solicitarRecuperacionPassword({
    required String identificador,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointRecuperarSolicitar,
      data: {'identificador': identificador.trim().toLowerCase()},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Recuperación de contraseña - Verificar código OTP
  Future<Map<String, dynamic>> verificarCodigoRecuperacion({
    required String identificador,
    required String codigoOtp,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointRecuperarVerificar,
      data: {
        'identificador': identificador.trim().toLowerCase(),
        'codigo': codigoOtp,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Recuperación de contraseña - Definir nueva clave
  Future<void> nuevaPasswordRecuperacion({
    required String identificador,
    required String codigoOtp,
    required String passwordNueva,
  }) async {
    await _apiClient.post(
      AppConstants.endpointRecuperarNuevaPassword,
      data: {
        'identificador': identificador.trim().toLowerCase(),
        'codigo': codigoOtp,
        'password_nueva': passwordNueva,
      },
    );
  }

  /// Actualizar perfil del usuario actual (username, nombre, teléfono, contraseña)
  Future<UsuarioModel> actualizarPerfil({
    String? username,
    String? nombreCompleto,
    String? telefono,
    String? passwordActual,
    String? passwordNueva,
  }) async {
    final payload = <String, dynamic>{};
    if (username != null && username.trim().isNotEmpty) {
      payload['username'] = username.trim().toLowerCase();
    }
    if (nombreCompleto != null) payload['nombre_completo'] = nombreCompleto.trim();
    if (telefono != null) payload['telefono'] = telefono.trim();
    if (passwordNueva != null && passwordNueva.isNotEmpty) {
      payload['password_actual'] = passwordActual;
      payload['password_nueva'] = passwordNueva;
    }

    await _apiClient.patch(
      AppConstants.endpointMe,
      data: payload,
    );

    return await obtenerPerfil();
  }

  /// Cerrar sesión local
  Future<void> logout() async {
    await _storageService.clearAll();
  }
}
