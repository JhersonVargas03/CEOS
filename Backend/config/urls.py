from django.contrib import admin
from django.urls import path, include
from config.views import health_check

urlpatterns = [
    # Monitoreo y Keep-Alive (Koyeb / UptimeRobot)
    path('health/', health_check, name='health-root'),
    path('api/health/', health_check, name='health-api'),

    path('admin/', admin.site.urls),
    path('api/', include('apps.usuarios.urls')),
    path('api/', include('apps.notificaciones.urls')),
    path('api/inventario/', include('apps.inventario.urls')),
    path('api/admin/backup/', include('apps.backup.urls')),
    path('api/backup/', include('apps.backup.urls')),
]
