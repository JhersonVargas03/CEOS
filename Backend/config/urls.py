from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('apps.usuarios.urls')),
    path('api/', include('apps.notificaciones.urls')),
    path('api/inventario/', include('apps.inventario.urls')),
    path('api/admin/backup/', include('apps.backup.urls')),
    path('api/backup/', include('apps.backup.urls')),
]
