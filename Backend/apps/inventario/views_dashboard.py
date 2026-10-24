import logging
from datetime import datetime, time
from django.db.models import Sum, Count, Q
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions

from .models import Material, Area, CategoriaMaterial
from .models_lotes import Lote
from .models_movimientos import MovimientoSalida
from .models_solicitudes import SolicitudMaterial

logger = logging.getLogger(__name__)


def parse_fecha_rango(request):
    """Auxiliar para parsear fecha_inicio y fecha_fin desde la query request."""
    f_ini_str = request.query_params.get('fecha_inicio')
    f_fin_str = request.query_params.get('fecha_fin')

    f_fin = timezone.now().date()
    if f_fin_str:
        try:
            f_fin = datetime.strptime(f_fin_str, '%Y-%m-%d').date()
        except ValueError:
            pass

    f_ini = f_fin - timezone.timedelta(days=30)
    if f_ini_str:
        try:
            f_ini = datetime.strptime(f_ini_str, '%Y-%m-%d').date()
        except ValueError:
            pass

    dt_inicio = timezone.make_aware(datetime.combine(f_ini, time.min))
    dt_fin = timezone.make_aware(datetime.combine(f_fin, time.max))

    return f_ini, f_fin, dt_inicio, dt_fin


class MaterialesMasUsadosView(APIView):
    """
    HU-220 (T-220.1 a T-220.3): Ranking de materiales más consumidos por SUM(cantidad_total) en MovimientoSalida.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        f_ini, f_fin, dt_inicio, dt_fin = parse_fecha_rango(request)

        area_id = request.query_params.get('area_id')
        categoria_id = request.query_params.get('categoria_id')
        limit = int(request.query_params.get('limit', 10))

        qs = MovimientoSalida.objects.filter(fecha_hora__range=(dt_inicio, dt_fin))

        if area_id:
            qs = qs.filter(material__area_id=area_id)
        if categoria_id:
            qs = qs.filter(material__categoria_id=categoria_id)

        agrupados = (
            qs.values(
                'material_id',
                'material__nombre',
                'material__area__nombre',
                'material__categoria__nombre'
            )
            .annotate(total_usado=Sum('cantidad_total'))
            .order_by('-total_usado')[:limit]
        )

        resultado = [
            {
                'material_id': item['material_id'],
                'material_nombre': item['material__nombre'],
                'area_nombre': item['material__area__nombre'] or '-',
                'categoria_nombre': item['material__categoria__nombre'] or '-',
                'total_usado': item['total_usado'] or 0
            }
            for item in agrupados
        ]

        return Response({
            'periodo': {
                'fecha_inicio': f_ini.strftime('%Y-%m-%d'),
                'fecha_fin': f_fin.strftime('%Y-%m-%d')
            },
            'materiales_mas_usados': resultado
        }, status=status.HTTP_200_OK)


class ReposicionPreventivaView(APIView):
    """
    HU-221 (T-221.1 a T-221.3): Consulta independiente del panel de materiales con solicitud preventiva.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        f_ini, f_fin, dt_inicio, dt_fin = parse_fecha_rango(request)

        qs = SolicitudMaterial.objects.filter(
            fecha_creacion__range=(dt_inicio, dt_fin),
            motivo__icontains='reposicion_preventiva'
        )

        agrupados = (
            qs.values(
                'material_id',
                'material__nombre',
                'material__area__nombre',
                'material__categoria__nombre'
            )
            .annotate(
                total_solicitudes=Count('id'),
                total_cantidad_solicitada=Sum('cantidad_solicitada')
            )
            .order_by('-total_solicitudes')
        )

        resultado = [
            {
                'material_id': item['material_id'],
                'material_nombre': item['material__nombre'],
                'area_nombre': item['material__area__nombre'] or '-',
                'categoria_nombre': item['material__categoria__nombre'] or '-',
                'total_solicitudes': item['total_solicitudes'],
                'total_cantidad_solicitada': item['total_cantidad_solicitada'] or 0
            }
            for item in agrupados
        ]

        return Response({
            'periodo': {
                'fecha_inicio': f_ini.strftime('%Y-%m-%d'),
                'fecha_fin': f_fin.strftime('%Y-%m-%d')
            },
            'solicitudes_preventivas': resultado
        }, status=status.HTTP_200_OK)


class ReporteGastosView(APIView):
    """
    HU-222 (T-222.1 a T-222.4): Reporte de gastos agrupado por categoría, por material y cálculo del porcentaje de costo incompleto.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        f_ini, f_fin, dt_inicio, dt_fin = parse_fecha_rango(request)

        lotes_qs = Lote.objects.filter(fecha_ingreso__gte=f_ini, fecha_ingreso__lte=f_fin)

        total_lotes = lotes_qs.count()
        lotes_sin_costo = lotes_qs.filter(Q(costo__isnull=True) | Q(costo=0) | Q(costo_registrado=False)).count()

        porcentaje_costo_incompleto = 0.0
        if total_lotes > 0:
            porcentaje_costo_incompleto = round((lotes_sin_costo / total_lotes) * 100, 2)

        # Gastos por categoría
        gastos_categoria = (
            lotes_qs.filter(costo__gt=0)
            .values('material__categoria_id', 'material__categoria__nombre')
            .annotate(total_gasto=Sum('costo'), total_lotes=Count('id'))
            .order_by('-total_gasto')
        )

        cat_resultado = [
            {
                'categoria_id': item['material__categoria_id'],
                'categoria_nombre': item['material__categoria__nombre'] or 'Sin Categoría',
                'total_gasto': float(item['total_gasto'] or 0),
                'total_lotes': item['total_lotes']
            }
            for item in gastos_categoria
        ]

        # Gastos por material
        gastos_material = (
            lotes_qs.filter(costo__gt=0)
            .values('material_id', 'material__nombre', 'material__categoria__nombre')
            .annotate(total_gasto=Sum('costo'), total_lotes=Count('id'))
            .order_by('-total_gasto')
        )

        mat_resultado = [
            {
                'material_id': item['material_id'],
                'material_nombre': item['material__nombre'],
                'categoria_nombre': item['material__categoria__nombre'] or '-',
                'total_gasto': float(item['total_gasto'] or 0),
                'total_lotes': item['total_lotes']
            }
            for item in gastos_material
        ]

        total_gasto_global = sum(item['total_gasto'] for item in cat_resultado)

        return Response({
            'periodo': {
                'fecha_inicio': f_ini.strftime('%Y-%m-%d'),
                'fecha_fin': f_fin.strftime('%Y-%m-%d')
            },
            'resumen_costos': {
                'total_lotes': total_lotes,
                'lotes_sin_costo': lotes_sin_costo,
                'porcentaje_costo_incompleto': porcentaje_costo_incompleto,
                'total_gasto_global': round(total_gasto_global, 2)
            },
            'gastos_por_categoria': cat_resultado,
            'gastos_por_material': mat_resultado
        }, status=status.HTTP_200_OK)
