from functools import wraps
from .models import RegistroAuditoria
import logging

logger = logging.getLogger(__name__)


class AuditService:
    @staticmethod
    def registrar_accion(usuario, accion, detalles=None, request=None):
        """Registra una acción auditable en la base de datos."""
        detalles = detalles or {}
        ip = None

        if request:
            x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
            if x_forwarded_for:
                ip = x_forwarded_for.split(',')[0].strip()
            else:
                ip = request.META.get('REMOTE_ADDR')

        registro = RegistroAuditoria.objects.create(
            usuario=usuario if (usuario and usuario.is_authenticated) else None,
            accion=accion,
            detalles=detalles,
            ip_address=ip
        )
        logger.info(f"[Auditoría] {registro}")
        return registro


def auditable(tipo_accion, extraer_detalles=None):
    """
    Decorador reutilizable para marcar endpoints que deben generar un registro automático de auditoría.

    Uso:
        @auditable('LOGIN_EXITOSO')
        def mi_view(request, ...):
            ...

        @auditable('CREACION_MATERIAL', extraer_detalles=lambda req, res: {'nombre': res.data.get('nombre')})
        def crear_material(request, ...):
            ...

    El decorador registra la acción DESPUÉS de que la view retorna una respuesta con código 2xx.
    """
    def decorator(view_func):
        @wraps(view_func)
        def _wrapped_view(request, *args, **kwargs):
            response = view_func(request, *args, **kwargs)
            if 200 <= response.status_code < 300:
                try:
                    usuario = getattr(request, 'user', None)
                    detalles = {}
                    if extraer_detalles and callable(extraer_detalles):
                        try:
                            detalles = extraer_detalles(request, response)
                        except Exception:
                            pass
                    AuditService.registrar_accion(usuario, tipo_accion, detalles, request=request)
                except Exception as e:
                    logger.warning(f"[Auditoría] Error al registrar acción {tipo_accion}: {e}")
            return response
        return _wrapped_view
    return decorator
