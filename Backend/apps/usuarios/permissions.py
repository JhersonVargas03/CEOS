from functools import wraps
from rest_framework.permissions import BasePermission
from rest_framework.exceptions import PermissionDenied
from .models import obtener_permisos_efectivos

class TienePermiso(BasePermission):
    """
    Permiso DRF reutilizable que verifica si el usuario autenticado posee el permiso requerido.
    Se define en la vista asignando `codigo_permiso = 'codigo_del_permiso'`.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        user = request.user
        if getattr(user, 'is_superuser', False) or getattr(user, 'rol', None) == 'SUPERADMIN':
            return True
        if hasattr(user, 'roles') and user.roles.filter(es_superadmin=True).exists():
            return True

        codigo_requerido = getattr(view, 'codigo_permiso', None)
        if not codigo_requerido:
            return True

        permisos_efectivos = obtener_permisos_efectivos(user)
        return codigo_requerido in permisos_efectivos


class EsSuperadmin(BasePermission):
    """
    Permiso DRF que exige que el usuario posea rol con es_superadmin=True o sea superusuario.
    """
    def has_permission(self, request, view):
        user = getattr(request, 'user', None)
        if not user or not user.is_authenticated:
            return False
        if getattr(user, 'is_superuser', False) or getattr(user, 'rol', None) == 'SUPERADMIN':
            return True
        return hasattr(user, 'roles') and user.roles.filter(es_superadmin=True).exists()


def requiere_permiso(codigo_permiso):
    """Decorador reutilizable para funciones de vista o métodos que verifica permisos efectivos."""
    def decorator(view_func):
        @wraps(view_func)
        def _wrapped_view(request, *args, **kwargs):
            user = getattr(request, 'user', None)
            if not user or not user.is_authenticated:
                raise PermissionDenied("Debe autenticarse para realizar esta acción.")

            permisos_efectivos = obtener_permisos_efectivos(user)
            if codigo_permiso not in permisos_efectivos:
                raise PermissionDenied(f"No tiene el permiso necesario ({codigo_permiso}) para realizar esta acción.")

            return view_func(request, *args, **kwargs)
        return _wrapped_view
    return decorator
