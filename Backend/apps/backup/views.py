import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions

from apps.usuarios.permissions import EsSuperadmin, TienePermiso
from .models import RegistroBackup
from .services import ejecutar_backup
from .tasks import generar_backup_manual_task

logger = logging.getLogger(__name__)


class BackupGenerarView(APIView):
    """
    T-302.1 a T-302.4: Endpoint POST /api/admin/backup/generar restringido a Superadmin para generar un backup manual.
    """
    permission_classes = [permissions.IsAuthenticated, EsSuperadmin]

    def post(self, request):
        async_execution = request.data.get('async', False)

        if async_execution:
            try:
                task_res = generar_backup_manual_task.delay(usuario_id=request.user.id)
                tarea_id = getattr(task_res, 'id', 'sync_task')
                return Response({
                    'mensaje': 'Proceso de respaldo manual iniciado asíncronamente.',
                    'tarea_id': str(tarea_id),
                    'estado': 'PENDIENTE'
                }, status=status.HTTP_202_ACCEPTED)
            except Exception as e:
                logger.warning(f"[BackupView] Fallo al encolar en Celery, ejecutando síncronamente: {e}")

        # Ejecución síncrona por defecto o fallback
        registro = ejecutar_backup(origen='MANUAL', usuario=request.user)

        if registro.exitoso:
            return Response({
                'mensaje': 'Respaldo de base de datos generado y despachado exitosamente.',
                'registro_id': registro.id,
                'nombre_archivo': registro.nombre_archivo,
                'tamano_bytes': registro.tamano_bytes,
                'origen': registro.origen,
                'fecha_hora': registro.fecha_hora.strftime('%Y-%m-%d %H:%M:%S')
            }, status=status.HTTP_201_CREATED)
        else:
            return Response({
                'error': 'Fallo al generar el respaldo de base de datos.',
                'detalles': registro.detalles_error
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class BackupEstadoView(APIView):
    """
    T-302.5: Endpoint GET /api/admin/backup/estado/{id} para consultar el estado del backup.
    """
    permission_classes = [permissions.IsAuthenticated, EsSuperadmin]

    def get(self, request, id=None):
        if id:
            registro = RegistroBackup.objects.filter(pk=id).first()
            if not registro:
                registro = RegistroBackup.objects.filter(tarea_id=id).first()
        else:
            registro = RegistroBackup.objects.first()

        if not registro:
            return Response({'error': 'Registro de respaldo no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            'registro_id': registro.id,
            'nombre_archivo': registro.nombre_archivo,
            'tamano_bytes': registro.tamano_bytes,
            'exitoso': registro.exitoso,
            'origen': registro.origen,
            'detalles_error': registro.detalles_error,
            'fecha_hora': registro.fecha_hora.strftime('%Y-%m-%d %H:%M:%S'),
            'usuario_solicitante': registro.usuario_solicitante.username if registro.usuario_solicitante else None
        }, status=status.HTTP_200_OK)


class BackupHistorialView(APIView):
    """
    HU-303 (T-303.1, T-303.2): Endpoint GET /api/admin/backup/historial con paginación y filtros.
    """
    permission_classes = [permissions.IsAuthenticated, EsSuperadmin]

    def get(self, request):
        qs = RegistroBackup.objects.select_related('usuario_solicitante').all()

        origen = request.query_params.get('origen')
        if origen:
            qs = qs.filter(origen=origen.upper())

        exitoso = request.query_params.get('exitoso')
        if exitoso is not None:
            es_exitoso = exitoso.lower() in ['true', '1']
            qs = qs.filter(exitoso=es_exitoso)

        total = qs.count()

        # Paginación básica
        try:
            page = int(request.query_params.get('page', 1))
            page_size = int(request.query_params.get('page_size', 20))
        except ValueError:
            page = 1
            page_size = 20

        start = (page - 1) * page_size
        end = start + page_size

        elementos = qs[start:end]

        resultado = [
            {
                'id': reg.id,
                'nombre_archivo': reg.nombre_archivo,
                'tamano_bytes': reg.tamano_bytes,
                'exitoso': reg.exitoso,
                'origen': reg.origen,
                'detalles_error': reg.detalles_error,
                'fecha_hora': reg.fecha_hora.strftime('%Y-%m-%d %H:%M:%S'),
                'usuario_solicitante': reg.usuario_solicitante.username if reg.usuario_solicitante else None
            }
            for reg in elementos
        ]

        return Response({
            'total': total,
            'page': page,
            'page_size': page_size,
            'resultados': resultado
        }, status=status.HTTP_200_OK)
