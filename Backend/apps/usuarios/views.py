from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.core.cache import cache
from django.conf import settings
from datetime import timedelta
import secrets, string, urllib.request, urllib.parse, json

from .models import (
    Usuario, Rol, Permiso, UsuarioRol, RolPermiso, CodigoRecuperacion,
    obtener_permisos_efectivos, invalidar_cache_permisos
)
from .serializers import (
    LoginSerializer, PerfilUsuarioSerializer, RolSerializer,
    RolCreateUpdateSerializer, PermisoSerializer, UsuarioAdminSerializer,
    UsuarioAdminCreateSerializer, UsuarioAdminUpdateSerializer, PerfilUpdateSerializer,
    SolicitarRecuperacionSerializer, VerificarCodigoRecuperacionSerializer,
    CambiarPasswordRecuperacionSerializer, validar_y_normalizar_telefono_bolivia
)
from .tokens import generar_tokens_para_usuario
from .permissions import TienePermiso
from apps.notificaciones.services import NotificationService
from apps.auditoria.services import AuditService


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Identificador y contraseña son requeridos'}, status=status.HTTP_400_BAD_REQUEST)

        identificador = serializer.validated_data['identificador'].strip().lower()
        password = serializer.validated_data['password']

        usuario = Usuario.objects.filter(
            Q(username=identificador) | Q(correo_interno=identificador)
        ).first()

        if not usuario:
            return Response({'error': 'Credenciales inválidas'}, status=status.HTTP_401_UNAUTHORIZED)

        if usuario.esta_bloqueado():
            minutos_restantes = int((usuario.bloqueado_hasta - timezone.now()).total_seconds() // 60) + 1
            NotificationService.notificar_bloqueo_cuenta(usuario)
            AuditService.registrar_accion(usuario, 'ACCESO_BLOQUEADO', {'motivo': 'Cuenta bloqueada por reintentos'}, request=request)
            return Response({
                'error': f'Cuenta bloqueada temporalmente por seguridad. Intente de nuevo en {minutos_restantes} minutos.'
            }, status=status.HTTP_403_FORBIDDEN)

        if not usuario.check_password(password):
            se_bloqueo = usuario.registrar_intento_fallido()
            AuditService.registrar_accion(usuario, 'LOGIN_FALLIDO', {'intentos': usuario.intentos_fallidos}, request=request)
            if se_bloqueo:
                NotificationService.notificar_bloqueo_cuenta(usuario)
                return Response({
                    'error': 'Ha superado el límite de 5 intentos fallidos. Su cuenta ha sido bloqueada por 15 minutos.'
                }, status=status.HTTP_403_FORBIDDEN)

            intentos_restantes = 5 - usuario.intentos_fallidos
            return Response({
                'error': f'Credenciales inválidas. Quedan {intentos_restantes} intento(s) antes del bloqueo de la cuenta.'
            }, status=status.HTTP_401_UNAUTHORIZED)

        usuario.resetear_intentos()
        tokens = generar_tokens_para_usuario(usuario)
        permisos_efectivos = list(obtener_permisos_efectivos(usuario))
        AuditService.registrar_accion(usuario, 'LOGIN_EXITOSO', request=request)

        return Response({
            'tokens': tokens,
            'usuario': PerfilUsuarioSerializer(usuario).data,
            'permisos_efectivos': permisos_efectivos
        }, status=status.HTTP_200_OK)


class TokenRefreshCustomView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response({'error': 'Token refresh es requerido'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            token = RefreshToken(refresh_token)
            user_id = token.payload.get('user_id')
            token_session_version = token.payload.get('session_version')

            usuario = Usuario.objects.get(id=user_id)

            if not usuario.activo:
                return Response({'error': 'La cuenta se encuentra inactiva'}, status=status.HTTP_403_FORBIDDEN)

            if token_session_version != usuario.session_version:
                return Response({'error': 'La sesión ha expirado o fue cerrada de forma remota'}, status=status.HTTP_401_UNAUTHORIZED)

            new_access_token = str(token.access_token)
            return Response({'access': new_access_token}, status=status.HTTP_200_OK)

        except (TokenError, Usuario.DoesNotExist):
            return Response({'error': 'Token refresh inválido o expirado'}, status=status.HTTP_401_UNAUTHORIZED)


class CerrarSesionRemotaView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, user_id=None):
        target_user_id = user_id if user_id else request.user.id
        target_user = get_object_or_404(Usuario, id=target_user_id)

        if target_user_id != request.user.id:
            permisos = obtener_permisos_efectivos(request.user)
            if 'gestionar_usuarios' not in permisos and not request.user.is_superuser:
                return Response({'error': 'No posee permisos para cerrar la sesión de otros usuarios'}, status=status.HTTP_403_FORBIDDEN)

        nueva_version = target_user.incrementar_session_version()
        AuditService.registrar_accion(
            request.user,
            'CIERRE_SESION_REMOTO',
            {'target_user_id': target_user.id, 'nueva_version': nueva_version},
            request=request
        )

        return Response({
            'mensaje': f'Todas las sesiones activas del usuario {target_user.username} fueron cerradas exitosamente.',
            'nueva_session_version': nueva_version
        }, status=status.HTTP_200_OK)


class PerfilUsuarioView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        permisos_efectivos = list(obtener_permisos_efectivos(request.user))
        return Response({
            'usuario': PerfilUsuarioSerializer(request.user).data,
            'permisos_efectivos': permisos_efectivos
        }, status=status.HTTP_200_OK)

    def patch(self, request):
        serializer = PerfilUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        usuario = request.user
        cambios = {}

        if 'username' in serializer.validated_data and serializer.validated_data['username']:
            nuevo_username = serializer.validated_data['username'].strip().lower()
            if usuario.username != nuevo_username:
                if Usuario.objects.filter(username=nuevo_username).exclude(id=usuario.id).exists():
                    return Response({
                        'error': f'El nombre de usuario "@{nuevo_username}" ya está siendo utilizado por otra persona. Por favor elige otro.'
                    }, status=status.HTTP_400_BAD_REQUEST)
                cambios['username_anterior'] = usuario.username
                cambios['username_nuevo'] = nuevo_username
                usuario.username = nuevo_username

        if 'nombre_completo' in serializer.validated_data:
            nuevo_nombre = serializer.validated_data['nombre_completo'].strip()
            if usuario.nombre_completo != nuevo_nombre:
                cambios['nombre_completo_anterior'] = usuario.nombre_completo
                cambios['nombre_completo_nuevo'] = nuevo_nombre
                usuario.nombre_completo = nuevo_nombre

        if 'telefono' in serializer.validated_data:
            nuevo_tel = serializer.validated_data['telefono']
            if usuario.telefono != nuevo_tel:
                cambios['telefono_anterior'] = usuario.telefono
                cambios['telefono_nuevo'] = nuevo_tel
                usuario.telefono = nuevo_tel

        if 'password_nueva' in serializer.validated_data and serializer.validated_data['password_nueva']:
            pwd_act = serializer.validated_data.get('password_actual')
            if not usuario.check_password(pwd_act):
                return Response({'error': 'La contraseña actual no es correcta.'}, status=status.HTTP_400_BAD_REQUEST)
            usuario.set_password(serializer.validated_data['password_nueva'])
            cambios['password_cambiada'] = True

        usuario.save()

        if cambios:
            AuditService.registrar_accion(
                request.user,
                'EDICION_PERFIL_PROPIO',
                cambios,
                request=request
            )

        permisos_efectivos = list(obtener_permisos_efectivos(usuario))
        return Response({
            'mensaje': 'Perfil actualizado exitosamente.',
            'usuario': PerfilUsuarioSerializer(usuario).data,
            'permisos_efectivos': permisos_efectivos
        }, status=status.HTTP_200_OK)


class PermisoListView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_roles'

    def get(self, request):
        permisos = Permiso.objects.all().order_by('codigo')
        return Response(PermisoSerializer(permisos, many=True).data, status=status.HTTP_200_OK)


class RolListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_roles'

    def get(self, request):
        roles = Rol.objects.all().order_by('nombre')
        return Response(RolSerializer(roles, many=True).data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = RolCreateUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        nombre = serializer.validated_data.get('nombre', '').strip()
        descripcion = serializer.validated_data.get('descripcion', '')
        permisos_ids = serializer.validated_data.get('permisos_ids')
        permisos_codigos = serializer.validated_data.get('permisos_codigos')

        if Rol.objects.filter(nombre__iexact=nombre).exists():
            return Response({'error': 'Ya existe un rol con ese nombre.'}, status=status.HTTP_400_BAD_REQUEST)

        rol = Rol.objects.create(nombre=nombre, descripcion=descripcion)

        if permisos_ids:
            permisos = Permiso.objects.filter(id__in=permisos_ids)
            for p in permisos:
                RolPermiso.objects.create(rol=rol, permiso=p)
        elif permisos_codigos:
            permisos = Permiso.objects.filter(codigo__in=permisos_codigos)
            for p in permisos:
                RolPermiso.objects.create(rol=rol, permiso=p)

        AuditService.registrar_accion(request.user, 'CREACION_ROL', {'rol_id': rol.id, 'nombre': rol.nombre}, request=request)

        return Response(RolSerializer(rol).data, status=status.HTTP_201_CREATED)


class RolDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_roles'

    def get(self, request, rol_id):
        rol = get_object_or_404(Rol, id=rol_id)
        return Response(RolSerializer(rol).data, status=status.HTTP_200_OK)

    def put(self, request, rol_id):
        return self._actualizar_rol(request, rol_id, partial=False)

    def patch(self, request, rol_id):
        return self._actualizar_rol(request, rol_id, partial=True)

    def _actualizar_rol(self, request, rol_id, partial=False):
        rol = get_object_or_404(Rol, id=rol_id)

        if rol.es_de_fabrica or rol.es_superadmin:
            return Response({'error': 'Los roles protegidos de fábrica no pueden ser modificados.'}, status=status.HTTP_403_FORBIDDEN)

        serializer = RolCreateUpdateSerializer(data=request.data, partial=partial)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        if 'nombre' in serializer.validated_data:
            nombre = serializer.validated_data['nombre'].strip()
            if Rol.objects.filter(nombre__iexact=nombre).exclude(id=rol.id).exists():
                return Response({'error': 'Ya existe otro rol con ese nombre.'}, status=status.HTTP_400_BAD_REQUEST)
            rol.nombre = nombre

        if 'descripcion' in serializer.validated_data:
            rol.descripcion = serializer.validated_data['descripcion']

        rol.save()

        permisos_ids = serializer.validated_data.get('permisos_ids')
        permisos_codigos = serializer.validated_data.get('permisos_codigos')

        if permisos_ids is not None or permisos_codigos is not None:
            RolPermiso.objects.filter(rol=rol).delete()
            if permisos_ids:
                permisos = Permiso.objects.filter(id__in=permisos_ids)
                for p in permisos:
                    RolPermiso.objects.create(rol=rol, permiso=p)
            elif permisos_codigos:
                permisos = Permiso.objects.filter(codigo__in=permisos_codigos)
                for p in permisos:
                    RolPermiso.objects.create(rol=rol, permiso=p)

        cache.clear()
        AuditService.registrar_accion(request.user, 'EDICION_ROL', {'rol_id': rol.id}, request=request)
        return Response(RolSerializer(rol).data, status=status.HTTP_200_OK)

    def delete(self, request, rol_id):
        rol = get_object_or_404(Rol, id=rol_id)

        if rol.es_de_fabrica or rol.es_superadmin:
            return Response({'error': 'Los roles protegidos de fábrica no pueden ser eliminados.'}, status=status.HTTP_403_FORBIDDEN)

        if UsuarioRol.objects.filter(rol=rol).exists():
            return Response({'error': 'No se puede eliminar un rol que está asignado a usuarios.'}, status=status.HTTP_400_BAD_REQUEST)

        rol.delete()
        cache.clear()
        AuditService.registrar_accion(request.user, 'ELIMINACION_ROL', {'rol_id': rol_id}, request=request)
        return Response({'mensaje': 'Rol eliminado exitosamente.'}, status=status.HTTP_200_OK)


class UsuarioRolesUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def patch(self, request, user_id):
        usuario = get_object_or_404(Usuario, id=user_id)
        roles_ids = request.data.get('roles_ids', [])

        UsuarioRol.objects.filter(usuario=usuario).delete()
        if roles_ids:
            roles = Rol.objects.filter(id__in=roles_ids)
            for r in roles:
                UsuarioRol.objects.create(usuario=usuario, rol=r)

        invalidar_cache_permisos(usuario)
        AuditService.registrar_accion(request.user, 'ASIGNACION_ROLES', {'target_user_id': usuario.id}, request=request)
        return Response({'mensaje': 'Roles actualizados exitosamente.'}, status=status.HTTP_200_OK)

    def put(self, request, user_id):
        return self.patch(request, user_id)


class UsuarioAdminListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def get(self, request):
        usuarios = Usuario.objects.all()
        return Response(UsuarioAdminSerializer(usuarios, many=True).data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = UsuarioAdminCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        username = serializer.validated_data['username'].strip().lower()
        correo_interno = serializer.validated_data['correo_interno'].strip().lower()
        telefono = serializer.validated_data.get('telefono', '')
        roles_ids = serializer.validated_data.get('roles_ids', [])

        if Usuario.objects.filter(username=username).exists():
            return Response({'error': 'El nombre de usuario ya se encuentra registrado.'}, status=status.HTTP_400_BAD_REQUEST)
        if Usuario.objects.filter(correo_interno=correo_interno).exists():
            return Response({'error': 'El correo interno ya se encuentra registrado.'}, status=status.HTTP_400_BAD_REQUEST)

        alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
        password_temporal = ''.join(secrets.choice(alphabet) for _ in range(12))

        nuevo_usuario = Usuario.objects.create_user(
            username=username,
            correo_interno=correo_interno,
            nombre_completo=serializer.validated_data.get('nombre_completo', '').strip(),
            password=password_temporal,
            telefono=telefono,
            primer_login_completado=False
        )

        if roles_ids:
            roles = Rol.objects.filter(id__in=roles_ids)
            for rol in roles:
                UsuarioRol.objects.get_or_create(usuario=nuevo_usuario, rol=rol)

        AuditService.registrar_accion(
            request.user,
            'CREACION_USUARIO',
            {'nuevo_usuario_id': nuevo_usuario.id, 'username': nuevo_usuario.username},
            request=request
        )

        return Response({
            'mensaje': 'Usuario creado exitosamente. Entregue la contraseña temporal al usuario.',
            'usuario': UsuarioAdminSerializer(nuevo_usuario).data,
            'password_temporal': password_temporal
        }, status=status.HTTP_201_CREATED)


class UsuarioAdminDetailUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def get(self, request, user_id):
        usuario = get_object_or_404(Usuario, id=user_id)
        return Response(UsuarioAdminSerializer(usuario).data, status=status.HTTP_200_OK)

    def patch(self, request, user_id):
        usuario = get_object_or_404(Usuario, id=user_id)
        serializer = UsuarioAdminUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        if 'nombre_completo' in serializer.validated_data:
            usuario.nombre_completo = serializer.validated_data['nombre_completo'].strip()

        if 'telefono' in serializer.validated_data:
            usuario.telefono = serializer.validated_data['telefono']

        usuario.save()

        if 'roles_ids' in serializer.validated_data:
            roles_ids = serializer.validated_data['roles_ids']
            UsuarioRol.objects.filter(usuario=usuario).delete()
            roles = Rol.objects.filter(id__in=roles_ids)
            for r in roles:
                UsuarioRol.objects.create(usuario=usuario, rol=r)
            invalidar_cache_permisos(usuario)

        AuditService.registrar_accion(request.user, 'EDICION_USUARIO', {'target_user_id': usuario.id}, request=request)
        return Response(UsuarioAdminSerializer(usuario).data, status=status.HTTP_200_OK)


class UsuarioAdminEstadoView(APIView):
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'gestionar_usuarios'

    def patch(self, request, user_id):
        usuario = get_object_or_404(Usuario, id=user_id)
        nuevo_estado = request.data.get('activo')
        if nuevo_estado is None:
            return Response({'error': 'El campo activo es requerido.'}, status=status.HTTP_400_BAD_REQUEST)

        if usuario == request.user and not nuevo_estado:
            return Response({'error': 'No puede desactivar su propia cuenta activa.'}, status=status.HTTP_400_BAD_REQUEST)

        usuario.activo = nuevo_estado
        usuario.save()

        if not nuevo_estado:
            usuario.incrementar_session_version()

        invalidar_cache_permisos(usuario)
        accion_name = 'REACTIVACION_CUENTA' if nuevo_estado else 'DESACTIVACION_CUENTA'
        AuditService.registrar_accion(request.user, accion_name, {'target_user_id': usuario.id}, request=request)

        return Response({
            'mensaje': f'El estado del usuario {usuario.username} fue cambiado a {"Activo" if nuevo_estado else "Inactivo"}.',
            'usuario': UsuarioAdminSerializer(usuario).data
        }, status=status.HTTP_200_OK)


# --- FLUJO OBLIGATORIO DE PRIMER LOGIN ---

class PrimerLoginCambiarPasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        password_actual = request.data.get('password_actual')
        password_nueva = request.data.get('password_nueva')

        if not password_nueva:
            return Response({'error': 'La nueva contraseña es requerida (campo: password_nueva).'}, status=status.HTTP_400_BAD_REQUEST)

        usuario = request.user

        # Si el cliente suministra password_actual, lo validamos
        if password_actual:
            if not usuario.check_password(password_actual):
                return Response({'error': 'La contraseña actual no es correcta.'}, status=status.HTTP_400_BAD_REQUEST)
            if password_actual == password_nueva:
                return Response({'error': 'La nueva contraseña debe ser diferente de la contraseña temporal.'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            if usuario.check_password(password_nueva):
                return Response({'error': 'La nueva contraseña debe ser diferente de la contraseña anterior.'}, status=status.HTTP_400_BAD_REQUEST)

        if len(password_nueva) < 8:
            return Response({'error': 'La nueva contraseña debe tener al menos 8 caracteres.'}, status=status.HTTP_400_BAD_REQUEST)

        usuario.set_password(password_nueva)
        usuario.save()

        AuditService.registrar_accion(usuario, 'PRIMER_LOGIN_CAMBIO_PASSWORD', request=request)
        return Response({'mensaje': 'Contraseña actualizada exitosamente.'}, status=status.HTTP_200_OK)


class PrimerLoginVincularTelegramView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        usuario = request.user
        token = usuario.generar_token_telegram()
        bot_name = getattr(settings, 'TELEGRAM_BOT_NAME', 'Ceos_Clibot')
        deep_link = f"https://t.me/{bot_name}?start={token}"
        return Response({
            'mensaje': f'Token de vinculación generado. Inicie conversación con el bot @{bot_name} en Telegram.',
            'telegram_token': token,
            'deep_link': deep_link,
            'bot_url': deep_link,
            'bot_username': bot_name,
        }, status=status.HTTP_200_OK)



class TelegramWebhookView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = request.data
        message = data.get('message', {})
        text = message.get('text', '')
        chat_id = message.get('chat', {}).get('id')

        if text.startswith('/start ') and chat_id:
            token = text.split('/start ')[1].strip()
            usuario = Usuario.objects.filter(telegram_token_vinculacion=token).first()
            if usuario:
                usuario.telegram_chat_id = str(chat_id)
                usuario.telegram_vinculado = True
                usuario.telegram_token_vinculacion = None
                usuario.save()
                AuditService.registrar_accion(usuario, 'TELEGRAM_VINCULADO', {'chat_id': str(chat_id)})
                NotificationService.enviar_mensaje(usuario, "¡Su cuenta de Telegram ha sido vinculada exitosamente al sistema CEOS!")
                return Response({'status': 'ok', 'mensaje': 'Cuenta vinculada exitosamente'}, status=status.HTTP_200_OK)

        return Response({'status': 'ignored'}, status=status.HTTP_200_OK)


def _procesar_telegram_updates(usuario_solicitante=None):
    """
    Función auxiliar que consulta getUpdates de Telegram y procesa los mensajes de vinculación.
    Útil en desarrollo local donde el webhook no es accesible públicamente.
    Retorna un dict con el resumen de actualizaciones procesadas.
    """
    token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
    if not token:
        return {'error': 'TELEGRAM_BOT_TOKEN no configurado', 'vinculados': 0}

    url = f"https://api.telegram.org/bot{token}/getUpdates"
    try:
        req = urllib.request.Request(url, method='GET')
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
    except Exception as e:
        return {'error': f'No se pudo contactar a Telegram: {e}', 'vinculados': 0}

    if not data.get('ok'):
        return {'error': 'Respuesta no OK de Telegram', 'vinculados': 0}

    vinculados = 0
    ignorados = 0
    max_update_id = None

    for update in data.get('result', []):
        update_id = update.get('update_id')
        if max_update_id is None or update_id > max_update_id:
            max_update_id = update_id

        message = update.get('message', {})
        text = message.get('text', '').strip()
        chat_id = message.get('chat', {}).get('id')

        if not chat_id:
            continue

        usuario = None
        if text.startswith('/start '):
            token_vincular = text.split('/start ', 1)[1].strip()
            usuario = Usuario.objects.filter(telegram_token_vinculacion=token_vincular).first()

        # Fallback: si el usuario envió solo /start, /star o cualquier texto al bot
        if not usuario:
            if usuario_solicitante and not usuario_solicitante.telegram_vinculado:
                usuario = usuario_solicitante
            else:
                pendientes = list(Usuario.objects.filter(telegram_vinculado=False, telegram_token_vinculacion__isnull=False))
                if len(pendientes) == 1:
                    usuario = pendientes[0]

        if usuario and not usuario.telegram_vinculado:
            usuario.telegram_chat_id = str(chat_id)
            usuario.telegram_vinculado = True
            usuario.telegram_token_vinculacion = None
            usuario.save()
            AuditService.registrar_accion(usuario, 'TELEGRAM_VINCULADO', {'chat_id': str(chat_id)})
            NotificationService.enviar_mensaje(usuario, "¡Su cuenta de Telegram ha sido vinculada exitosamente al sistema CEOS!")
            vinculados += 1
        else:
            ignorados += 1

    # Marcar los updates como procesados en Telegram (offset = último id + 1)
    if max_update_id is not None:
        confirm_url = f"https://api.telegram.org/bot{token}/getUpdates"
        payload = json.dumps({'offset': max_update_id + 1}).encode('utf-8')
        try:
            req2 = urllib.request.Request(confirm_url, data=payload,
                                          headers={'Content-Type': 'application/json'}, method='POST')
            urllib.request.urlopen(req2, timeout=5)
        except Exception:
            pass  # Si falla el ack, no es crítico

    return {'vinculados': vinculados, 'ignorados': ignorados, 'updates_procesados': len(data.get('result', []))}


class TelegramProcesarUpdatesView(APIView):
    """
    Endpoint de uso exclusivo en desarrollo local cuando no hay webhook.
    Llama a getUpdates de Telegram y procesa vinculaciones de cuentas pendientes.
    POST /api/telegram/procesar-updates
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        resultado = _procesar_telegram_updates(usuario_solicitante=request.user)
        if 'error' in resultado:
            return Response(resultado, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return Response(resultado, status=status.HTTP_200_OK)


class PrimerLoginEnviarOtpView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):

        usuario = request.user
        telefono_req = request.data.get('telefono')
        if telefono_req:
            try:
                telefono_normalizado = validar_y_normalizar_telefono_bolivia(telefono_req)
                usuario.telefono = telefono_normalizado
                usuario.save(update_fields=['telefono'])
            except Exception as e:
                mensaje_err = str(getattr(e, 'detail', e))
                if isinstance(mensaje_err, list) and mensaje_err:
                    mensaje_err = str(mensaje_err[0])
                return Response({'error': mensaje_err}, status=status.HTTP_400_BAD_REQUEST)

        if not usuario.telefono:
            return Response({'error': 'El usuario no tiene un número de teléfono configurado. Ingrese su número de 8 dígitos.'}, status=status.HTTP_400_BAD_REQUEST)

        otp = usuario.generar_otp_telefono()
        NotificationService.enviar_mensaje(usuario, f"CEOS - Su código de verificación es: {otp}")
        return Response({
            'mensaje': f'Código OTP de 6 dígitos enviado al teléfono {usuario.telefono}.',
            'telefono': usuario.telefono,
            'otp_prueba': otp if settings.DEBUG else None
        }, status=status.HTTP_200_OK)


class PrimerLoginConfirmarOtpView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        otp = request.data.get('otp') or request.data.get('codigo')
        if not otp:
            return Response({'error': 'Código OTP requerido (campo: codigo u otp).'}, status=status.HTTP_400_BAD_REQUEST)

        usuario = request.user

        if not usuario.otp_telefono_codigo or usuario.otp_telefono_codigo != str(otp).strip():
            return Response({'error': 'El código OTP es incorrecto.'}, status=status.HTTP_400_BAD_REQUEST)

        if usuario.otp_telefono_expiracion and timezone.now() > usuario.otp_telefono_expiracion:
            return Response({'error': 'El código OTP ha expirado. Solicite uno nuevo.'}, status=status.HTTP_400_BAD_REQUEST)

        usuario.telefono_verificado = True
        usuario.otp_telefono_codigo = None
        usuario.save()

        AuditService.registrar_accion(usuario, 'TELEFONO_VERIFICADO', request=request)
        return Response({'mensaje': 'Teléfono verificado exitosamente.'}, status=status.HTTP_200_OK)



class PrimerLoginFinalizarView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        usuario = request.user

        usuario.primer_login_completado = True
        usuario.save()

        AuditService.registrar_accion(usuario, 'PRIMER_LOGIN_FINALIZADO', request=request)

        tokens = generar_tokens_para_usuario(usuario)
        permisos_efectivos = list(obtener_permisos_efectivos(usuario))

        return Response({
            'mensaje': '¡Primer inicio de sesión completado exitosamente! Bienvenido a CEOS.',
            'tokens': tokens,
            'usuario': UsuarioAdminSerializer(usuario).data,
            'permisos_efectivos': permisos_efectivos
        }, status=status.HTTP_200_OK)


# --- ÉPICA 1.E — RECUPERACIÓN DE CONTRASEÑA ---

class SolicitarRecuperacionView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = SolicitarRecuperacionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Identificador es requerido'}, status=status.HTTP_400_BAD_REQUEST)

        identificador = serializer.validated_data['identificador'].strip().lower()

        usuario = Usuario.objects.filter(
            Q(username=identificador) | Q(correo_interno=identificador)
        ).first()

        mensaje_generico = "Si el usuario ingresado existe en el sistema, se ha enviado un código de verificación por el canal de mensajería configurado."

        if not usuario or not usuario.activo:
            return Response({'mensaje': mensaje_generico}, status=status.HTTP_200_OK)

        rate_key_cooldown = f"recuperar_cooldown_user_{usuario.id}"
        if cache.get(rate_key_cooldown):
            return Response({
                'error': 'Debe esperar al menos 60 segundos entre solicitudes de recuperación.'
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

        rate_key_count = f"recuperar_count_user_{usuario.id}"
        count = cache.get(rate_key_count, 0)
        if count >= 5:
            return Response({
                'error': 'Ha superado el límite de 5 solicitudes de recuperación por hora. Intente más tarde.'
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

        cache.set(rate_key_cooldown, True, timeout=60)
        cache.set(rate_key_count, count + 1, timeout=3600)

        codigo_digits = ''.join(secrets.choice(string.digits) for _ in range(6))
        expiracion = timezone.now() + timedelta(minutes=10)

        CodigoRecuperacion.objects.filter(usuario=usuario, usado=False).update(usado=True)

        CodigoRecuperacion.objects.create(
            usuario=usuario,
            codigo=codigo_digits,
            expiracion=expiracion
        )

        msg = f"🔑 <b>CÓDIGO DE RECUPERACIÓN CEOS</b> 🔑\n\nHola {usuario.username},\nTu código de verificación para restablecer la contraseña es: <b>{codigo_digits}</b>\n\nEste código expira en 10 minutos."
        NotificationService.enviar_mensaje(usuario, msg)

        AuditService.registrar_accion(usuario, 'SOLICITUD_RECUPERACION', request=request)

        return Response({'mensaje': mensaje_generico}, status=status.HTTP_200_OK)


class VerificarCodigoRecuperacionView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = VerificarCodigoRecuperacionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        identificador = serializer.validated_data['identificador'].strip().lower()
        codigo = serializer.validated_data['codigo'].strip()

        usuario = Usuario.objects.filter(
            Q(username=identificador) | Q(correo_interno=identificador)
        ).first()

        if not usuario or not usuario.activo:
            return Response({'error': 'El código de recuperación es inválido o ha expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        cod_rec = CodigoRecuperacion.objects.filter(usuario=usuario, usado=False).first()

        if not cod_rec or not cod_rec.esta_vigente():
            return Response({'error': 'El código de recuperación es inválido o ha expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        if cod_rec.codigo != codigo:
            cod_rec.registrar_intento_fallido()
            intentos_restantes = 3 - cod_rec.intentos_fallidos
            return Response({
                'error': f'Código de recuperación incorrecto. Quedan {max(0, intentos_restantes)} intento(s).'
            }, status=status.HTTP_400_BAD_REQUEST)

        AuditService.registrar_accion(usuario, 'VERIFICACION_CODIGO_RECUPERACION', request=request)
        return Response({'mensaje': 'Código verificado correctamente. Proceda a ingresar su nueva contraseña.'}, status=status.HTTP_200_OK)


class NuevaPasswordRecuperacionView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = CambiarPasswordRecuperacionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        identificador = serializer.validated_data['identificador'].strip().lower()
        codigo = serializer.validated_data['codigo'].strip()
        nueva_password = serializer.validated_data['nueva_password']

        usuario = Usuario.objects.filter(
            Q(username=identificador) | Q(correo_interno=identificador)
        ).first()

        if not usuario or not usuario.activo:
            return Response({'error': 'El código de recuperación es inválido o ha expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        cod_rec = CodigoRecuperacion.objects.filter(usuario=usuario, usado=False).first()

        if not cod_rec or not cod_rec.esta_vigente() or cod_rec.codigo != codigo:
            return Response({'error': 'El código de recuperación es inválido o ha expirado.'}, status=status.HTTP_400_BAD_REQUEST)

        usuario.set_password(nueva_password)
        usuario.incrementar_session_version()
        usuario.save()

        cod_rec.usado = True
        cod_rec.save()

        AuditService.registrar_accion(usuario, 'CAMBIO_PASSWORD_RECUPERACION', request=request)

        return Response({'mensaje': 'Contraseña restablecida exitosamente. Por favor inicie sesión con su nueva clave.'}, status=status.HTTP_200_OK)
