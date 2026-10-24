from django.urls import path
from .views import (
    ConfiguracionSistemaView, ConfiguracionAlertasInventarioView,
    NotificacionListView, NotificacionMarcarLeidaView,
    NotificacionMarcarTodasLeidasView
)

urlpatterns = [
    path('admin/config', ConfiguracionSistemaView.as_view(), name='admin_config'),
    path('admin/config/canal-mensajeria', ConfiguracionSistemaView.as_view(), name='admin_config_canal'),
    path('admin/config/alertas-inventario', ConfiguracionAlertasInventarioView.as_view(), name='admin_config_alertas'),
    path('notificaciones', NotificacionListView.as_view(), name='notificaciones_list'),
    path('notificaciones/', NotificacionListView.as_view()),
    path('notificaciones/<int:notificacion_id>/marcar-leida', NotificacionMarcarLeidaView.as_view(), name='notificacion_marcar_leida'),
    path('notificaciones/<int:notificacion_id>/marcar-leida/', NotificacionMarcarLeidaView.as_view()),
    path('notificaciones/marcar-todas-leidas', NotificacionMarcarTodasLeidasView.as_view(), name='notificacion_marcar_todas_leidas'),
    path('notificaciones/marcar-todas-leidas/', NotificacionMarcarTodasLeidasView.as_view()),
]
