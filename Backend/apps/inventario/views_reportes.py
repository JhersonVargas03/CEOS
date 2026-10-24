import logging
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from apps.usuarios.permissions import TienePermiso
from apps.auditoria.services import AuditService
from apps.notificaciones.services import NotificationService
from .services_reportes import obtener_datos_reporte_inventario, generar_pdf_reporte_inventario
from .models_reportes import ReporteGenerado
from .models import Area, CategoriaMaterial
from apps.usuarios.models import Usuario

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────────────────────
# Helper: guarda los metadatos del reporte en BD
# ──────────────────────────────────────────────────────────────────────────────
def _registrar_reporte(request_user, datos_reporte, fecha_inicio_raw, fecha_fin_raw,
                       area_id=None, categoria_id=None, usuario_id=None,
                       enviado_mensajeria=False, nombre_archivo=''):
    """Persiste los parámetros de generación en ReporteGenerado (sin guardar el PDF)."""
    from .services_reportes import parse_fecha
    try:
        area_obj = Area.objects.filter(pk=area_id).first() if area_id else None
        cat_obj = CategoriaMaterial.objects.filter(pk=categoria_id).first() if categoria_id else None
        usr_filtrado = Usuario.objects.filter(pk=usuario_id).first() if usuario_id else None

        ReporteGenerado.objects.create(
            generado_por=request_user,
            fecha_inicio=parse_fecha(fecha_inicio_raw) or datos_reporte.get('_fecha_inicio'),
            fecha_fin=parse_fecha(fecha_fin_raw) or datos_reporte.get('_fecha_fin'),
            area=area_obj,
            categoria=cat_obj,
            usuario_filtrado=usr_filtrado,
            total_ingresos=datos_reporte.get('total_ingresos', 0),
            total_salidas=datos_reporte.get('total_salidas', 0),
            total_ajustes=datos_reporte.get('total_ajustes', 0),
            total_solicitudes=datos_reporte.get('total_solicitudes', 0),
            enviado_por_mensajeria=enviado_mensajeria,
            nombre_archivo=nombre_archivo,
        )
    except Exception as exc:
        logger.warning(f"[_registrar_reporte] No se pudo guardar metadatos: {exc}")


# ──────────────────────────────────────────────────────────────────────────────
# T-217: Generación y descarga de PDF
# ──────────────────────────────────────────────────────────────────────────────
class ReportePDFView(APIView):
    """
    T-217.1 a T-217.5, HU-218 y HU-219:
    POST /api/inventario/reportes/pdf — generación bajo demanda.
    Guarda metadatos en ReporteGenerado para el historial.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        data = request.data or {}
        fecha_inicio = data.get('fecha_inicio')
        fecha_fin = data.get('fecha_fin')
        area_id = data.get('area_id')
        categoria_id = data.get('categoria_id')
        usuario_id = data.get('usuario_id')
        enviar_mensajeria = data.get('enviar_mensajeria', False)

        # 1. Agregación de datos
        datos_reporte = obtener_datos_reporte_inventario(
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            area_id=area_id,
            categoria_id=categoria_id,
            usuario_id=usuario_id,
            usuario_generador=request.user
        )

        # 2. Generar PDF con WeasyPrint
        try:
            pdf_bytes = generar_pdf_reporte_inventario(datos_reporte)
        except Exception as e:
            logger.error(f"[ReportePDFView] Error generando PDF: {e}")
            return Response(
                {'error': f'Error al generar el documento PDF: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        filename = (
            f"reporte_inventario_"
            f"{datos_reporte['fecha_emision_str'].replace('/', '').replace(':', '').replace(' ', '_')}"
            f".pdf"
        )

        # 3. Auditoría T-217.5
        AuditService.registrar_accion(
            usuario=request.user,
            accion='GENERACION_REPORTE_PDF',
            detalles={
                'fecha_inicio': str(fecha_inicio),
                'fecha_fin': str(fecha_fin),
                'usuario_filtrado_id': usuario_id,
                'enviar_mensajeria': enviar_mensajeria,
                'archivo': filename,
            },
            request=request
        )

        # 4. HU-219: Entrega dual vía mensajería si se solicita
        if enviar_mensajeria:
            mensaje = (
                f"📊 <b>REPORTE DE INVENTARIO GENERADO</b> 📊\n\n"
                f"<b>Período:</b> {datos_reporte['periodo_str']}\n"
                f"<b>Generado Por:</b> {datos_reporte['usuario_generador']}\n"
                f"<b>Filtro Usuario:</b> {datos_reporte['usuario_filtrado_str']}\n\n"
                f"• Lotes Ingresados: {datos_reporte['total_ingresos']}\n"
                f"• Salidas Registradas: {datos_reporte['total_salidas']}\n"
                f"• Ajustes de Inventario: {datos_reporte['total_ajustes']}\n"
                f"• Solicitudes Material: {datos_reporte['total_solicitudes']}\n\n"
                f"<i>El documento PDF ha sido generado y adjuntado.</i>"
            )
            NotificationService.enviar_documento(request.user, pdf_bytes, filename, caption=mensaje)
            AuditService.registrar_accion(
                usuario=request.user,
                accion='ENVIO_REPORTE_MENSAJERIA',
                detalles={'canal': 'mensajeria', 'archivo': filename},
                request=request
            )

        # 5. T-REPORTE-HIST.1: Persistir metadatos del reporte
        _registrar_reporte(
            request_user=request.user,
            datos_reporte=datos_reporte,
            fecha_inicio_raw=fecha_inicio,
            fecha_fin_raw=fecha_fin,
            area_id=area_id,
            categoria_id=categoria_id,
            usuario_id=usuario_id,
            enviado_mensajeria=bool(enviar_mensajeria),
            nombre_archivo=filename,
        )

        # 6. Retornar PDF (JSON Base64 para app móvil, o attachment binario)
        formato = data.get('formato') or request.query_params.get('formato')
        if formato == 'json' or 'application/json' in request.headers.get('Accept', ''):
            import base64
            return Response({
                'mensaje': 'Reporte PDF generado exitosamente.',
                'filename': filename,
                'pdf_base64': base64.b64encode(pdf_bytes).decode('utf-8'),
                'resumen': {
                    'periodo_str': datos_reporte['periodo_str'],
                    'fecha_emision_str': datos_reporte['fecha_emision_str'],
                    'usuario_generador': str(datos_reporte['usuario_generador']),
                    'usuario_filtrado_str': datos_reporte['usuario_filtrado_str'],
                    'total_ingresos': datos_reporte['total_ingresos'],
                    'total_salidas': datos_reporte['total_salidas'],
                    'total_ajustes': datos_reporte['total_ajustes'],
                    'total_solicitudes': datos_reporte['total_solicitudes'],
                }
            }, status=status.HTTP_200_OK)

        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response


# ──────────────────────────────────────────────────────────────────────────────
# T-219: Envío de reporte por mensajería
# ──────────────────────────────────────────────────────────────────────────────
class ReporteEnviarMensajeriaView(APIView):
    """
    T-219.2: POST /api/inventario/reportes/enviar-por-mensajeria
    Guarda metadatos en ReporteGenerado con enviado_por_mensajeria=True.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        data = request.data or {}
        fecha_inicio = data.get('fecha_inicio')
        fecha_fin = data.get('fecha_fin')
        area_id = data.get('area_id')
        categoria_id = data.get('categoria_id')
        usuario_id = data.get('usuario_id')

        datos_reporte = obtener_datos_reporte_inventario(
            fecha_inicio=fecha_inicio,
            fecha_fin=fecha_fin,
            area_id=area_id,
            categoria_id=categoria_id,
            usuario_id=usuario_id,
            usuario_generador=request.user
        )

        import os
        from django.conf import settings
        from django.utils import timezone
        fecha_str = timezone.now().strftime('%Y%m%d_%H%M%S')
        filename = f"reporte_inventario_{fecha_str}.pdf"
        temp_dir = getattr(settings, 'BACKUP_TEMP_DIR', os.path.join(settings.BASE_DIR, 'tmp_backups'))
        os.makedirs(temp_dir, exist_ok=True)
        ruta_pdf = os.path.join(temp_dir, filename)

        pdf_bytes = None
        try:
            pdf_bytes = generar_pdf_reporte_inventario(datos_reporte)
            with open(ruta_pdf, 'wb') as f:
                f.write(pdf_bytes)
        except Exception as e:
            logger.warning(f"[ReporteEnviarMensajeriaView] No se pudo generar PDF: {e}")

        mensaje = (
            f"📊 <b>REPORTE DE INVENTARIO CEOS</b> 📊\n\n"
            f"<b>Período:</b> {datos_reporte['periodo_str']}\n"
            f"<b>Solicitado Por:</b> {datos_reporte['usuario_generador']}\n"
            f"<b>Filtro Usuario:</b> {datos_reporte['usuario_filtrado_str']}\n\n"
            f"• Lotes Ingresados: {datos_reporte['total_ingresos']}\n"
            f"• Salidas Registradas: {datos_reporte['total_salidas']}\n"
            f"• Ajustes de Inventario: {datos_reporte['total_ajustes']}\n"
            f"• Solicitudes Material: {datos_reporte['total_solicitudes']}\n"
        )

        if pdf_bytes and os.path.exists(ruta_pdf):
            NotificationService.enviar_documento(request.user, ruta_pdf, filename, caption=mensaje)
            try:
                os.remove(ruta_pdf)
            except Exception:
                pass
        else:
            NotificationService.enviar_mensaje(request.user, mensaje)

        AuditService.registrar_accion(
            usuario=request.user,
            accion='ENVIO_REPORTE_MENSAJERIA',
            detalles={
                'fecha_inicio': str(fecha_inicio),
                'fecha_fin': str(fecha_fin),
                'usuario_filtrado_id': usuario_id,
            },
            request=request
        )

        # Persistir metadatos con flag de mensajería
        _registrar_reporte(
            request_user=request.user,
            datos_reporte=datos_reporte,
            fecha_inicio_raw=fecha_inicio,
            fecha_fin_raw=fecha_fin,
            area_id=area_id,
            categoria_id=categoria_id,
            usuario_id=usuario_id,
            enviado_mensajeria=True,
            nombre_archivo=filename,
        )

        return Response({
            'mensaje': 'Reporte generado y enviado exitosamente por mensajería.',
            'resumen': {
                'titulo': datos_reporte['titulo'],
                'periodo_str': datos_reporte['periodo_str'],
                'fecha_emision_str': datos_reporte['fecha_emision_str'],
                'usuario_generador': str(datos_reporte['usuario_generador']),
                'usuario_filtrado_str': datos_reporte['usuario_filtrado_str'],
                'total_ingresos': datos_reporte['total_ingresos'],
                'total_salidas': datos_reporte['total_salidas'],
                'total_ajustes': datos_reporte['total_ajustes'],
                'total_solicitudes': datos_reporte['total_solicitudes'],
            }
        }, status=status.HTTP_200_OK)


# ──────────────────────────────────────────────────────────────────────────────
# T-REPORTE-HIST.2: Historial y regeneración
# ──────────────────────────────────────────────────────────────────────────────
class ReporteHistorialView(APIView):
    """
    T-REPORTE-HIST.2: GET /api/inventario/reportes/historial
    Lista los últimos 50 reportes generados por el usuario autenticado
    (admins ven todos; usuarios normales sólo los suyos).
    Incluye los parámetros listos para regenerar el PDF con un solo toque.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from apps.usuarios.models import Rol
        user = request.user

        # Admins ven el historial completo; el resto sólo el suyo
        es_admin = user.roles.filter(nombre__in=['Administrador', 'Superadministrador']).exists()
        qs = ReporteGenerado.objects.select_related(
            'generado_por', 'area', 'categoria', 'usuario_filtrado'
        )
        if not es_admin:
            qs = qs.filter(generado_por=user)

        reportes = qs[:50]

        data = []
        for r in reportes:
            fi_str = r.fecha_inicio.strftime('%d/%m/%Y') if r.fecha_inicio else None
            ff_str = r.fecha_fin.strftime('%d/%m/%Y') if r.fecha_fin else None
            if fi_str and ff_str:
                periodo_str = f"{fi_str} → {ff_str}"
            elif fi_str:
                periodo_str = f"Desde {fi_str}"
            elif ff_str:
                periodo_str = f"Hasta {ff_str}"
            else:
                periodo_str = "Histórico general"

            data.append({
                'id': r.id,
                'generado_por': r.generado_por.username if r.generado_por else 'Sistema',
                'generado_por_nombre': (
                    getattr(r.generado_por, 'nombre_completo', '') or r.generado_por.username
                ) if r.generado_por else 'Sistema',
                'generado_en': r.generado_en.strftime('%d/%m/%Y %H:%M'),
                'periodo': periodo_str,
                'fecha_inicio': str(r.fecha_inicio) if r.fecha_inicio else None,
                'fecha_fin': str(r.fecha_fin) if r.fecha_fin else None,
                'area': r.area.nombre if r.area else None,
                'categoria': r.categoria.nombre if r.categoria else None,
                'usuario_filtrado': r.usuario_filtrado.username if r.usuario_filtrado else None,
                'totales': {
                    'ingresos': r.total_ingresos,
                    'salidas': r.total_salidas,
                    'ajustes': r.total_ajustes,
                    'solicitudes': r.total_solicitudes,
                },
                'enviado_mensajeria': r.enviado_por_mensajeria,
                'enviado_por_mensajeria': r.enviado_por_mensajeria,
                'nombre_archivo': r.nombre_archivo,
                # Parámetros listos para regenerar desde la app
                'parametros_regeneracion': r.parametros_regeneracion,
            })

        return Response({'reportes': data, 'total': len(data)}, status=status.HTTP_200_OK)
