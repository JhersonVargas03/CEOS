import logging
from django.utils import timezone
from celery import shared_task
from apps.usuarios.models import Usuario
from apps.notificaciones.models import ConfiguracionSistema, NotificacionApp
from apps.notificaciones.services import NotificationService
from .models import Material
from .models_lotes import Lote

logger = logging.getLogger(__name__)


def materiales_bajo_minimo():
    """
    T-215.2: Retorna lista de materiales cuyo stock total disponible es menor o igual a su stock mínimo.
    Retorna lista de tuplas: (material, stock_total_disponible, stock_minimo)
    """
    resultado = []
    materiales = Material.objects.filter(activo=True)
    for m in materiales:
        stock = m.stock_total_disponible()
        if stock <= m.stock_minimo:
            resultado.append((m, stock, m.stock_minimo))
    return resultado


def lotes_con_alerta_vencimiento_activa():
    """
    T-215.3: Retorna lotes activos (cantidad_disponible > 0) con alerta de vencimiento activa o caducados.
    Retorna lista de tuplas: (lote, dias_restantes)
    """
    resultado = []
    hoy = timezone.now().date()
    lotes = Lote.objects.filter(cantidad_disponible__gt=0).select_related('material')
    for lote in lotes:
        if lote.fecha_caducidad:
            dias_restantes = (lote.fecha_caducidad - hoy).days
            if lote.alerta_activa or dias_restantes <= 30:
                resultado.append((lote, dias_restantes))
    return resultado


@shared_task
def revisar_alertas_inventario():
    """
    T-215.1 a T-215.6 & T-216.3: Tarea periódica de Celery para la revisión y envío de alertas de inventario.
    """
    # T-216.3: Respetar toggle global de alertas de inventario
    if not ConfiguracionSistema.obtener_alertas_inventario_activas():
        logger.info("[revisar_alertas_inventario] Alertas de inventario desactivadas en la configuración global.")
        return {
            'status': 'desactivado',
            'alertas_enviadas': 0
        }

    hoy_fecha = timezone.now().date()
    encargados = Usuario.objects.filter(
        activo=True,
        roles__permisos__codigo__in=['aprobar_solicitud', 'ajustar_inventario']
    ).distinct()

    if not encargados.exists():
        logger.warning("[revisar_alertas_inventario] No hay encargados o gestores activos para recibir alertas.")
        return {
            'status': 'sin_encargados',
            'alertas_enviadas': 0
        }

    alertas_enviadas_count = 0

    # 1. Procesar materiales bajo mínimo (T-215.2)
    materiales_alerta = materiales_bajo_minimo()
    for mat, stock, stock_min in materiales_alerta:
        # T-215.6: Evitar duplicados el mismo día
        ya_notificado = NotificacionApp.objects.filter(
            tipo='alerta_stock_bajo',
            referencia_id=mat.id,
            fecha_creacion__date=hoy_fecha
        ).exists()

        if not ya_notificado:
            titulo = f"⚠️ Alerta Stock Bajo: {mat.nombre}"
            mensaje = (
                f"El material '{mat.nombre}' (Área: {mat.area.nombre}) presenta un stock disponible de "
                f"{stock} {mat.unidad_medida}(s), estando por debajo del mínimo configurado ({stock_min})."
            )
            # Crear notificación in-app para cada encargado
            for encargado in encargados:
                NotificacionApp.objects.create(
                    usuario=encargado,
                    titulo=titulo,
                    mensaje=mensaje,
                    tipo='alerta_stock_bajo',
                    referencia_id=mat.id
                )
                # Notificación externa (Telegram/WhatsApp)
                NotificationService.enviar_mensaje(
                    encargado,
                    f"<b>{titulo}</b>\n\n{mensaje}"
                )

            alertas_enviadas_count += 1

    # 2. Procesar lotes próximos a vencer o vencidos (T-215.3)
    lotes_alerta = lotes_con_alerta_vencimiento_activa()
    for lote, dias_restantes in lotes_alerta:
        # T-215.6: Evitar duplicados el mismo día
        ya_notificado = NotificacionApp.objects.filter(
            tipo='alerta_vencimiento',
            referencia_id=lote.id,
            fecha_creacion__date=hoy_fecha
        ).exists()

        if not ya_notificado:
            if dias_restantes < 0:
                titulo = f"🚨 Lote Vencido: {lote.codigo_lote} ({lote.material.nombre})"
                mensaje = (
                    f"El lote {lote.codigo_lote} del material '{lote.material.nombre}' venció el "
                    f"{lote.fecha_caducidad}. Cantidad disponible afectada: {lote.cantidad_disponible}."
                )
            else:
                titulo = f"⚠️ Lote Próximo a Vencer: {lote.codigo_lote} ({lote.material.nombre})"
                mensaje = (
                    f"El lote {lote.codigo_lote} del material '{lote.material.nombre}' vencerá en {dias_restantes} días "
                    f"({lote.fecha_caducidad}). Cantidad disponible actual: {lote.cantidad_disponible}."
                )

            for encargado in encargados:
                NotificacionApp.objects.create(
                    usuario=encargado,
                    titulo=titulo,
                    mensaje=mensaje,
                    tipo='alerta_vencimiento',
                    referencia_id=lote.id
                )
                NotificationService.enviar_mensaje(
                    encargado,
                    f"<b>{titulo}</b>\n\n{mensaje}"
                )

            alertas_enviadas_count += 1

    logger.info(f"[revisar_alertas_inventario] Finalizado. Alertas procesadas hoy: {alertas_enviadas_count}")
    return {
        'status': 'completado',
        'alertas_enviadas': alertas_enviadas_count
    }
