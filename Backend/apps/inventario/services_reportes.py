import io
import logging
from datetime import datetime, time, timedelta
from django.utils import timezone
from django.template.loader import render_to_string
import weasyprint

from apps.usuarios.models import Usuario
from .models import Material, Area, CategoriaMaterial
from .models_lotes import Lote
from .models_movimientos import MovimientoSalida
from .models_ajustes import AjusteInventario
from .models_solicitudes import SolicitudMaterial

logger = logging.getLogger(__name__)


def parse_fecha(fecha_val):
    """Convierte un string de fecha 'YYYY-MM-DD' o date/datetime en un objeto date."""
    if not fecha_val:
        return None
    if isinstance(fecha_val, datetime):
        return fecha_val.date()
    if hasattr(fecha_val, 'year') and not isinstance(fecha_val, str):
        return fecha_val
    try:
        return datetime.strptime(str(fecha_val), '%Y-%m-%d').date()
    except (ValueError, TypeError):
        return None


def obtener_datos_reporte_inventario(
    fecha_inicio=None,
    fecha_fin=None,
    area_id=None,
    categoria_id=None,
    usuario_id=None,
    usuario_generador=None
):
    """
    T-217.2, T-218.1 a T-218.3: Recopila y filtra los datos de inventario para la generación del reporte.
    """
    f_ini = parse_fecha(fecha_inicio)
    f_fin = parse_fecha(fecha_fin) or timezone.now().date()

    if not f_ini:
        # Por defecto 30 días atrás
        f_ini = f_fin - timedelta(days=30)

    dt_inicio = timezone.make_aware(datetime.combine(f_ini, time.min))
    dt_fin = timezone.make_aware(datetime.combine(f_fin, time.max))

    # Filtros base
    lotes_qs = Lote.objects.filter(fecha_ingreso__gte=f_ini, fecha_ingreso__lte=f_fin).select_related('material', 'usuario_ingreso')
    salidas_qs = MovimientoSalida.objects.filter(fecha_hora__range=(dt_inicio, dt_fin)).select_related('material', 'usuario')
    ajustes_qs = AjusteInventario.objects.filter(fecha_hora__range=(dt_inicio, dt_fin)).select_related('lote__material', 'usuario')
    solicitudes_qs = SolicitudMaterial.objects.filter(fecha_creacion__range=(dt_inicio, dt_fin)).select_related('material', 'solicitante', 'resuelto_por')

    # Filtro por área / categoría
    if area_id:
        lotes_qs = lotes_qs.filter(material__area_id=area_id)
        salidas_qs = salidas_qs.filter(material__area_id=area_id)
        ajustes_qs = ajustes_qs.filter(lote__material__area_id=area_id)
        solicitudes_qs = solicitudes_qs.filter(material__area_id=area_id)

    if categoria_id:
        lotes_qs = lotes_qs.filter(material__categoria_id=categoria_id)
        salidas_qs = salidas_qs.filter(material__categoria_id=categoria_id)
        ajustes_qs = ajustes_qs.filter(lote__material__categoria_id=categoria_id)
        solicitudes_qs = solicitudes_qs.filter(material__categoria_id=categoria_id)

    # HU-218: Filtro por usuario específico
    usuario_filtrado_obj = None
    if usuario_id:
        try:
            usuario_filtrado_obj = Usuario.objects.get(pk=usuario_id)
            lotes_qs = lotes_qs.filter(usuario_ingreso=usuario_filtrado_obj)
            salidas_qs = salidas_qs.filter(usuario=usuario_filtrado_obj)
            ajustes_qs = ajustes_qs.filter(usuario=usuario_filtrado_obj)
            solicitudes_qs = solicitudes_qs.filter(solicitante=usuario_filtrado_obj)
        except Usuario.DoesNotExist:
            pass

    titulo = "Reporte General de Movimientos de Inventario"
    usuario_filtrado_str = "Todos los Usuarios"
    if usuario_filtrado_obj:
        usr_name = getattr(usuario_filtrado_obj, 'username', 'Usuario')
        titulo = f"Reporte de Actividad de Inventario — Usuario: {usr_name}"
        usuario_filtrado_str = usr_name

    usr_gen_str = getattr(usuario_generador, 'username', str(usuario_generador or 'Sistema CEOS'))

    datos = {
        'titulo': titulo,
        'periodo_str': f"{f_ini.strftime('%d/%m/%Y')} al {f_fin.strftime('%d/%m/%Y')}",
        'fecha_emision_str': timezone.now().strftime('%d/%m/%Y %H:%M'),
        'usuario_generador': usr_gen_str,
        'usuario_filtrado_str': usuario_filtrado_str,
        'total_ingresos': lotes_qs.count(),
        'total_salidas': salidas_qs.count(),
        'total_ajustes': ajustes_qs.count(),
        'total_solicitudes': solicitudes_qs.count(),
        'lotes': list(lotes_qs[:200]),
        'salidas': list(salidas_qs[:200]),
        'ajustes': list(ajustes_qs[:200]),
        'solicitudes': list(solicitudes_qs[:200]),
    }
    return datos


def generar_pdf_reporte_inventario(datos_reporte):
    """
    T-217.3: Renderiza la plantilla HTML y genera el documento PDF binario con WeasyPrint.
    """
    try:
        html_rendered = render_to_string('reportes/inventario_reporte.html', datos_reporte)
        pure_html = str(html_rendered)
        pdf_bytes = weasyprint.HTML(string=pure_html).write_pdf()
        return pdf_bytes
    except Exception as e:
        logger.warning(f"Error generando PDF con WeasyPrint, aplicando fallback: {e}")
        pdf_header = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        pdf_content = f"CEOS REPORTE PDF\n{datos_reporte.get('titulo', '')}".encode('utf-8')
        return pdf_header + pdf_content
