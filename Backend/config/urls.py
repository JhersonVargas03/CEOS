from django.contrib import admin
from django.urls import path, include
from config.views import health_check, app_version_check

urlpatterns = [
    # Monitoreo y Keep-Alive (Koyeb / UptimeRobot)
    path('health/', health_check, name='health-root'),
    path('api/health/', health_check, name='health-api'),

    # Verificación de actualizaciones móviles (OTA / In-App Updates)
    path('api/sistema/version/', app_version_check, name='sistema-version'),
    path('api/version/', app_version_check, name='api-version'),

    path('admin/', admin.site.urls),
    path('api/', include('apps.usuarios.urls')),
    path('api/', include('apps.notificaciones.urls')),
    path('api/inventario/', include('apps.inventario.urls')),
    path('api/admin/backup/', include('apps.backup.urls')),
    path('api/backup/', include('apps.backup.urls')),
]
