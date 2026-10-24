from django.urls import path
from .views import BackupGenerarView, BackupEstadoView, BackupHistorialView

urlpatterns = [
    path('generar', BackupGenerarView.as_view(), name='backup_generar'),
    path('estado/<str:id>', BackupEstadoView.as_view(), name='backup_estado'),
    path('historial', BackupHistorialView.as_view(), name='backup_historial'),
]
