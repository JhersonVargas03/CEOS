class AppConstants {
  AppConstants._();

  // Storage Keys
  static const String keyAccessToken = 'ceos_access_token';
  static const String keyRefreshToken = 'ceos_refresh_token';
  static const String keySessionVersion = 'ceos_session_version';
  static const String keyUserData = 'ceos_user_data';
  static const String keyPrimerLoginPendiente = 'ceos_primer_login_pendiente';

  // Endpoints - Auth
  static const String endpointLogin = '/auth/login';
  static const String endpointRefresh = '/auth/refresh';
  static const String endpointMe = '/auth/me';

  // Endpoints - Recuperación de Contraseña
  static const String endpointRecuperarSolicitar = '/auth/recuperar/solicitar';
  static const String endpointRecuperarVerificar = '/auth/recuperar/verificar';
  static const String endpointRecuperarNuevaPassword = '/auth/recuperar/nueva-contrasena';

  // Endpoints - Primer Login
  static const String endpointPrimerLoginPassword = '/auth/primer-login/cambiar-password';
  static const String endpointPrimerLoginTelegram = '/auth/primer-login/vincular-telegram';
  static const String endpointPrimerLoginEnviarOtp = '/auth/primer-login/enviar-otp-telefono';
  static const String endpointPrimerLoginConfirmarOtp = '/auth/primer-login/confirmar-telefono';
  static const String endpointPrimerLoginFinalizar = '/auth/primer-login/finalizar';
  static const String endpointTelegramProcesarUpdates = '/telegram/procesar-updates';

  // Endpoints - Inventario
  static const String endpointAreas = '/inventario/areas';
  static const String endpointCategorias = '/inventario/categorias';
  static const String endpointMateriales = '/inventario/materiales';
  static const String endpointLotes = '/inventario/lotes';
  static const String endpointSalidas = '/inventario/salidas';
  static const String endpointAjustes = '/inventario/ajustes';
  static const String endpointSolicitudes = '/inventario/solicitudes';
  static const String endpointReportesPdf = '/inventario/reportes/pdf';
  static const String endpointReportesEnviarMensajeria = '/inventario/reportes/enviar-por-mensajeria';
  static const String endpointReportesHistorial = '/inventario/reportes/historial';
  static const String endpointDashboardMasUsados = '/inventario/dashboard/mas-usados';
  static const String endpointDashboardReposicion = '/inventario/dashboard/reposicion-preventiva';
  static const String endpointReporteGastos = '/inventario/reportes/gastos';
  static const String endpointIconos = '/inventario/iconos-disponibles';

  // Endpoints - Admin
  static const String endpointAdminUsuarios = '/admin/usuarios';
  static const String endpointAdminRoles = '/admin/roles';
  static const String endpointAdminPermisos = '/admin/permisos';
  static const String endpointAdminConfig = '/admin/config';
  static const String endpointAdminConfigCanal = '/admin/config/canal-mensajeria';
  static const String endpointAdminConfigAlertas = '/admin/config/alertas-inventario';

  // Endpoints - Backup
  static const String endpointBackupGenerar = '/admin/backup/generar';
  static const String endpointBackupEstado = '/admin/backup/estado';
  static const String endpointBackupHistorial = '/admin/backup/historial';

  // Endpoints - Notificaciones & Auditoría
  static const String endpointNotificaciones = '/notificaciones';
  static const String endpointHistorialUsuario = '/usuarios';
  static const String endpointAdminAuditoria = '/admin/auditoria';
}
