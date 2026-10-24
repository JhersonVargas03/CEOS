from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.contrib.auth import get_user_model
from .models import RegistroAuditoria
from apps.usuarios.models import obtener_permisos_efectivos

Usuario = get_user_model()


class HistorialUsuarioView(APIView):
    """
    GET /usuarios/{id}/historial
    Devuelve el historial de auditoría de un usuario con paginación.
    - El propio usuario puede consultar su historial.
    - Un usuario con 'gestionar_usuarios' o 'ver_reportes_globales' puede consultar cualquier historial.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, user_id):
        target_user = get_object_or_404(Usuario, id=user_id)

        # Control de acceso
        es_propio = request.user.id == target_user.id
        if not es_propio:
            permisos = obtener_permisos_efectivos(request.user)
            puede_ver = 'gestionar_usuarios' in permisos or 'ver_reportes_globales' in permisos
            if not puede_ver:
                return Response(
                    {'error': 'No tiene permisos para consultar el historial de otro usuario.'},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Paginación simple por query params
        page = int(request.query_params.get('page', 1))
        page_size = min(int(request.query_params.get('page_size', 20)), 100)
        offset = (page - 1) * page_size

        qs = RegistroAuditoria.objects.filter(usuario=target_user).order_by('-fecha_hora')
        total = qs.count()
        registros = qs[offset:offset + page_size]

        data = [
            {
                'id': r.id,
                'accion': r.accion,
                'detalles': r.detalles,
                'ip_address': r.ip_address,
                'fecha_hora': r.fecha_hora.isoformat(),
            }
            for r in registros
        ]

        return Response({
            'total': total,
            'page': page,
            'page_size': page_size,
            'results': data
        }, status=status.HTTP_200_OK)


class AuditoriaGlobalView(APIView):
    """
    GET /api/admin/auditoria
    Devuelve todos los registros de auditoría del sistema con filtros y paginación.
    Accesible para Superadmin o usuarios con permisos 'ver_reportes_globales' o 'gestionar_usuarios'.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        es_sa = getattr(user, 'is_superuser', False) or (hasattr(user, 'roles') and user.roles.filter(es_superadmin=True).exists())
        if not es_sa:
            permisos = obtener_permisos_efectivos(user)
            if 'ver_reportes_globales' not in permisos and 'gestionar_usuarios' not in permisos:
                return Response({'error': 'No tiene permisos para consultar la auditoría del sistema.'}, status=status.HTTP_403_FORBIDDEN)

        qs = RegistroAuditoria.objects.select_related('usuario').all().order_by('-fecha_hora')

        accion = request.query_params.get('accion')
        if accion:
            from django.db.models import Q
            acc_val = accion.strip().upper()
            if acc_val in ('INVENTARIO', 'INVENTARIOS'):
                qs = qs.filter(
                    Q(accion__icontains='MATERIAL') |
                    Q(accion__icontains='LOTE') |
                    Q(accion__icontains='SALIDA') |
                    Q(accion__icontains='AJUSTE') |
                    Q(accion__icontains='SOLICITUD') |
                    Q(accion__icontains='AREA') |
                    Q(accion__icontains='CATEGORIA')
                )
            elif acc_val in ('USUARIOS', 'ROLES', 'USUARIOS_ROLES'):
                qs = qs.filter(
                    Q(accion__icontains='ROL') |
                    Q(accion__icontains='USUARIO') |
                    Q(accion__icontains='PASSWORD') |
                    Q(accion__icontains='TELEGRAM') |
                    Q(accion__icontains='TELEFONO')
                )
            elif acc_val in ('ACCESOS', 'LOGIN'):
                qs = qs.filter(
                    Q(accion__icontains='LOGIN') |
                    Q(accion__icontains='ACCESO') |
                    Q(accion__icontains='LOGOUT')
                )
            elif acc_val in ('RESPALDOS', 'BACKUP'):
                qs = qs.filter(
                    Q(accion__icontains='BACKUP') |
                    Q(accion__icontains='RESPALDO')
                )
            elif acc_val in ('REPORTES', 'REPORTE'):
                qs = qs.filter(
                    Q(accion__icontains='REPORTE')
                )
            else:
                qs = qs.filter(accion__icontains=accion.strip())

        usuario_id = request.query_params.get('usuario_id')
        if usuario_id:
            qs = qs.filter(usuario_id=usuario_id)

        search = request.query_params.get('search')
        if search:
            from django.db.models import Q
            qs = qs.filter(Q(accion__icontains=search) | Q(usuario__username__icontains=search) | Q(detalles__icontains=search))

        total = qs.count()
        try:
            page = int(request.query_params.get('page', 1))
            page_size = min(int(request.query_params.get('page_size', 20)), 100)
        except ValueError:
            page = 1
            page_size = 20

        offset = (page - 1) * page_size
        registros = qs[offset:offset + page_size]

        data = [
            {
                'id': r.id,
                'accion': r.accion,
                'usuario': r.usuario.username if r.usuario else 'Sistema',
                'usuario_id': r.usuario_id,
                'detalles': r.detalles,
                'ip_address': r.ip_address,
                'fecha_hora': r.fecha_hora.isoformat(),
            }
            for r in registros
        ]

        return Response({
            'total': total,
            'page': page,
            'page_size': page_size,
            'results': data
        }, status=status.HTTP_200_OK)

