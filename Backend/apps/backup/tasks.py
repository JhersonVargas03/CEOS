import logging
from .services import ejecutar_backup

logger = logging.getLogger(__name__)

try:
    from celery import shared_task
except ImportError:
    # Fallback si celery no está presente en el entorno de pruebas
    def shared_task(func):
        func.delay = lambda *args, **kwargs: func(*args, **kwargs)
        return func


@shared_task
def generar_backup_diario():
    """
    T-301.1: Tarea programada (Celery Beat) para la generación automática diaria de respaldos.
    """
    logger.info("[Celery] Iniciando tarea programada: generar_backup_diario")
    registro = ejecutar_backup(origen='AUTOMATICO')
    return {
        'registro_id': registro.id,
        'exitoso': registro.exitoso,
        'nombre_archivo': registro.nombre_archivo
    }


@shared_task
def generar_backup_manual_task(usuario_id=None):
    """
    T-302.4: Tarea asíncrona de Celery para respaldos manuales bajo demanda.
    """
    from apps.usuarios.models import Usuario
    usuario = None
    if usuario_id:
        try:
            usuario = Usuario.objects.get(pk=usuario_id)
        except Usuario.DoesNotExist:
            pass

    logger.info(f"[Celery] Iniciando tarea de backup manual solicitada por usuario {usuario}")
    registro = ejecutar_backup(origen='MANUAL', usuario=usuario)
    return {
        'registro_id': registro.id,
        'exitoso': registro.exitoso,
        'nombre_archivo': registro.nombre_archivo
    }
