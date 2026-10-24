from django.urls import path
from .views import (
    LoginView, TokenRefreshCustomView, CerrarSesionRemotaView, PerfilUsuarioView,
    PermisoListView, RolListCreateView, RolDetailView, UsuarioRolesUpdateView,
    UsuarioAdminListCreateView, UsuarioAdminDetailUpdateView, UsuarioAdminEstadoView,
    PrimerLoginCambiarPasswordView, PrimerLoginVincularTelegramView, TelegramWebhookView,
    TelegramProcesarUpdatesView,
    PrimerLoginEnviarOtpView, PrimerLoginConfirmarOtpView, PrimerLoginFinalizarView,
    SolicitarRecuperacionView, VerificarCodigoRecuperacionView, NuevaPasswordRecuperacionView
)
from apps.auditoria.views import HistorialUsuarioView, AuditoriaGlobalView

urlpatterns = [
    # Auth
    path('auth/login', LoginView.as_view(), name='auth_login'),
    path('auth/refresh', TokenRefreshCustomView.as_view(), name='auth_refresh'),
    path('auth/me', PerfilUsuarioView.as_view(), name='auth_me'),

    # Recuperación de Contraseña (Épica 1.E)
    path('auth/recuperar/solicitar', SolicitarRecuperacionView.as_view(), name='auth_recuperar_solicitar'),
    path('auth/recuperar/verificar', VerificarCodigoRecuperacionView.as_view(), name='auth_recuperar_verificar'),
    path('auth/recuperar/nueva-contrasena', NuevaPasswordRecuperacionView.as_view(), name='auth_recuperar_nueva_password'),

    # Admin Usuarios
    path('admin/usuarios', UsuarioAdminListCreateView.as_view(), name='admin_usuarios_list_create'),
    path('admin/usuarios/<int:user_id>', UsuarioAdminDetailUpdateView.as_view(), name='admin_usuario_detail_update'),
    path('admin/usuarios/<int:user_id>/estado', UsuarioAdminEstadoView.as_view(), name='admin_usuario_estado'),
    path('admin/usuarios/<int:user_id>/cerrar-sesion', CerrarSesionRemotaView.as_view(), name='admin_cerrar_sesion'),
    path('admin/usuarios/<int:user_id>/roles', UsuarioRolesUpdateView.as_view(), name='admin_usuario_roles'),

    # Primer Login Flujo Obligatorio
    path('auth/primer-login/cambiar-password', PrimerLoginCambiarPasswordView.as_view(), name='primer_login_cambiar_password'),
    path('auth/primer-login/vincular-telegram', PrimerLoginVincularTelegramView.as_view(), name='primer_login_vincular_telegram'),
    path('telegram/webhook', TelegramWebhookView.as_view(), name='telegram_webhook'),
    path('telegram/procesar-updates', TelegramProcesarUpdatesView.as_view(), name='telegram_procesar_updates'),
    path('auth/primer-login/enviar-otp-telefono', PrimerLoginEnviarOtpView.as_view(), name='primer_login_enviar_otp'),
    path('auth/primer-login/confirmar-telefono', PrimerLoginConfirmarOtpView.as_view(), name='primer_login_confirmar_otp'),
    path('auth/primer-login/finalizar', PrimerLoginFinalizarView.as_view(), name='primer_login_finalizar'),

    # Admin Roles & Permisos
    path('admin/permisos', PermisoListView.as_view(), name='admin_permisos_list'),
    path('admin/roles', RolListCreateView.as_view(), name='admin_roles_list_create'),
    path('admin/roles/<int:rol_id>', RolDetailView.as_view(), name='admin_rol_detail'),

    # Auditoría
    path('admin/auditoria', AuditoriaGlobalView.as_view(), name='admin_auditoria'),

    # Historial de Auditoría (Épica 1.F)
    path('usuarios/<int:user_id>/historial', HistorialUsuarioView.as_view(), name='usuario_historial'),
]

