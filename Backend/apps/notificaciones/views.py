from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from .models import ConfiguracionSistema, NotificacionApp
from .serializers import (
    ConfiguracionSistemaSerializer, CanalMensajeriaUpdateSerializer,
    AlertasInventarioUpdateSerializer, NotificacionAppSerializer
)
from apps.usuarios.permissions import TienePermiso
from apps.auditoria.services import AuditService


class ConfiguracionSistemaView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def get(self, request):
        config = ConfiguracionSistema.objects.first()
        if not config:
            config = ConfiguracionSistema.objects.create(canal_mensajeria_activo='TELEGRAM')
        return Response(ConfiguracionSistemaSerializer(config).data, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = CanalMensajeriaUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Canal inválido', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        config, _ = ConfiguracionSistema.objects.get_or_create(id=1)
        nuevo_canal = serializer.validated_data['canal_mensajeria_activo']
        config.canal_mensajeria_activo = nuevo_canal
        config.actualizado_por = request.user
        config.save()

        AuditService.registrar_accion(
            request.user,
            'CAMBIO_CANAL_MENSAJERIA',
            {'nuevo_canal': nuevo_canal},
            request=request
        )

        return Response({
            'mensaje': f'Canal de mensajería cambiado exitosamente a {nuevo_canal}.',
            'configuracion': ConfiguracionSistemaSerializer(config).data
        }, status=status.HTTP_200_OK)


class ConfiguracionAlertasInventarioView(APIView):
    """T-216.2: Endpoint PATCH /admin/config/alertas-inventario para activar/desactivar alertas de stock."""
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def patch(self, request):
        serializer = AlertasInventarioUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        config, _ = ConfiguracionSistema.objects.get_or_create(id=1)
        activas = serializer.validated_data['alertas_inventario_activas']
        config.alertas_inventario_activas = activas
        config.actualizado_por = request.user
        config.save()

        AuditService.registrar_accion(
            request.user,
            'CAMBIO_ALERTAS_INVENTARIO',
            {'alertas_inventario_activas': activas},
            request=request
        )

        return Response({
            'mensaje': f'Alertas de inventario {"activadas" if activas else "desactivadas"} exitosamente.',
            'configuracion': ConfiguracionSistemaSerializer(config).data
        }, status=status.HTTP_200_OK)


class NotificacionListView(APIView):
    """
    T-211.7: Endpoint GET /notificaciones para listar las notificaciones in-app del usuario autenticado.
    Filtro opcional: ?leida=false.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        qs = NotificacionApp.objects.filter(usuario=request.user)
        leida_str = request.query_params.get('leida')
        if leida_str is not None:
            if leida_str.lower() in ['false', '0']:
                qs = qs.filter(leida=False)
            elif leida_str.lower() in ['true', '1']:
                qs = qs.filter(leida=True)

        return Response(NotificacionAppSerializer(qs, many=True).data)


class NotificacionMarcarLeidaView(APIView):
    """Endpoint PATCH/POST /notificaciones/<id>/marcar-leida para marcar como leída una notificación in-app."""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, notificacion_id):
        es_sa = getattr(request.user, 'is_superuser', False) or getattr(request.user, 'es_superadmin', False) or (hasattr(request.user, 'roles') and request.user.roles.filter(es_superadmin=True).exists())
        if es_sa:
            notificacion = get_object_or_404(NotificacionApp, id=notificacion_id)
        else:
            notificacion = get_object_or_404(NotificacionApp, id=notificacion_id, usuario=request.user)
        notificacion.leida = True
        notificacion.save()
        return Response(NotificacionAppSerializer(notificacion).data)

    def post(self, request, notificacion_id):
        return self.patch(request, notificacion_id)


class NotificacionMarcarTodasLeidasView(APIView):
    """Endpoint POST /notificaciones/marcar-todas-leidas para marcar todas las notificaciones como leídas."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        actualizadas = NotificacionApp.objects.filter(usuario=request.user, leida=False).update(leida=True)
        return Response({'mensaje': f'{actualizadas} notificaciones marcadas como leídas.'}, status=status.HTTP_200_OK)
