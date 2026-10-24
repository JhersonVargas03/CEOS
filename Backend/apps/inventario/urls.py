from django.urls import path
from .views import (
    AreaListCreateView, AreaDetailView,
    CategoriaListCreateView, CategoriaDetailView,
    IconosDisponiblesView,
    MaterialListCreateView, MaterialDetailView,
    LoteCreateView, MaterialLotesListView, MaterialMovimientosListView,
    SalidaCreateView,
    AjusteListCreateView,
    SolicitudListCreateView, SolicitudDetailView,
    SolicitudCancelarView, SolicitudResolverView,
)
from .views_reportes import ReportePDFView, ReporteEnviarMensajeriaView, ReporteHistorialView
from .views_dashboard import MaterialesMasUsadosView, ReposicionPreventivaView, ReporteGastosView

urlpatterns = [
    # Catálogo de Íconos (HU-304 / Épica 4.A extensión)
    path('iconos-disponibles', IconosDisponiblesView.as_view(), name='inventario_iconos_disponibles'),

    # Áreas
    path('areas', AreaListCreateView.as_view(), name='inventario_areas_list_create'),
    path('areas/<int:area_id>', AreaDetailView.as_view(), name='inventario_area_detail'),

    # Categorías
    path('categorias', CategoriaListCreateView.as_view(), name='inventario_categorias_list_create'),
    path('categorias/<int:categoria_id>', CategoriaDetailView.as_view(), name='inventario_categoria_detail'),

    # Materiales
    path('materiales', MaterialListCreateView.as_view(), name='inventario_materiales_list_create'),
    path('materiales/<int:material_id>', MaterialDetailView.as_view(), name='inventario_material_detail'),

    # Lotes (Épica 2.B)
    path('lotes', LoteCreateView.as_view(), name='inventario_lotes_create'),
    path('materiales/<int:material_id>/lotes', MaterialLotesListView.as_view(), name='inventario_material_lotes_list'),
    path('materiales/<int:material_id>/movimientos', MaterialMovimientosListView.as_view(), name='inventario_material_movimientos_list'),

    # Salidas FEFO (Épica 2.C)
    path('salidas', SalidaCreateView.as_view(), name='inventario_salidas_create'),

    # Ajustes (Épica 2.D)
    path('ajustes', AjusteListCreateView.as_view(), name='inventario_ajustes_list_create'),

    # Solicitudes (Épica 2.E)
    path('solicitudes', SolicitudListCreateView.as_view(), name='inventario_solicitudes_list_create'),
    path('solicitudes/<int:solicitud_id>', SolicitudDetailView.as_view(), name='inventario_solicitud_detail'),
    path('solicitudes/<int:solicitud_id>/cancelar', SolicitudCancelarView.as_view(), name='inventario_solicitud_cancelar'),
    path('solicitudes/<int:solicitud_id>/resolver', SolicitudResolverView.as_view(), name='inventario_solicitud_resolver'),

    # Reportes PDF y Mensajería (Épica 2.G)
    path('reportes/pdf', ReportePDFView.as_view(), name='inventario_reportes_pdf'),
    path('reportes/enviar-por-mensajeria', ReporteEnviarMensajeriaView.as_view(), name='inventario_reportes_enviar_mensajeria'),
    # T-REPORTE-HIST.2: Historial de reportes generados
    path('reportes/historial', ReporteHistorialView.as_view(), name='inventario_reportes_historial'),

    # Dashboard y Gastos (Épica 2.H)
    path('dashboard/mas-usados', MaterialesMasUsadosView.as_view(), name='inventario_dashboard_mas_usados'),
    path('dashboard/reposicion-preventiva', ReposicionPreventivaView.as_view(), name='inventario_dashboard_reposicion_preventiva'),
    path('reportes/gastos', ReporteGastosView.as_view(), name='inventario_reportes_gastos'),
]
