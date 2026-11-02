import os
import json
import logging
import urllib.request
import urllib.parse
from django.conf import settings
from apps.usuarios.models import Usuario
from apps.auditoria.services import AuditService
from apps.notificaciones.services import TelegramChannel

logger = logging.getLogger(__name__)

class TelegramBotService:
    DEFAULT_WEBHOOK_URL = "https://ceos-qb08.onrender.com/api/telegram/webhook"

    @classmethod
    def get_token(cls):
        return getattr(settings, 'TELEGRAM_BOT_TOKEN', '')

    @classmethod
    def get_secret(cls):
        return getattr(settings, 'TELEGRAM_WEBHOOK_SECRET', 'ceos_telegram_secret_token_key_2026')

    @classmethod
    def obtener_info_webhook(cls):
        token = cls.get_token()
        if not token:
            return {'ok': False, 'error': 'TELEGRAM_BOT_TOKEN no configurado'}
        url = f"https://api.telegram.org/bot{token}/getWebhookInfo"
        try:
            req = urllib.request.Request(url, method='GET')
            with urllib.request.urlopen(req, timeout=10) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            logger.error(f"[TelegramBotService] Error consultando webhook info: {e}")
            return {'ok': False, 'error': str(e)}

    @classmethod
    def configurar_webhook(cls, webhook_url=None):
        token = cls.get_token()
        if not token:
            return {'ok': False, 'error': 'TELEGRAM_BOT_TOKEN no configurado'}

        target_url = webhook_url or os.environ.get('TELEGRAM_WEBHOOK_URL') or cls.DEFAULT_WEBHOOK_URL
        secret = cls.get_secret()

        url = f"https://api.telegram.org/bot{token}/setWebhook"
        payload = json.dumps({
            "url": target_url,
            "secret_token": secret,
            "drop_pending_updates": False,
            "allowed_updates": ["message"]
        }).encode('utf-8')

        headers = {'Content-Type': 'application/json'}
        req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                res = json.loads(resp.read().decode('utf-8'))
                logger.info(f"[TelegramBotService] setWebhook a {target_url}: {res}")
                return res
        except Exception as e:
            logger.error(f"[TelegramBotService] Error configurando webhook: {e}")
            return {'ok': False, 'error': str(e)}

    @classmethod
    def eliminar_webhook(cls, drop_pending_updates=False):
        token = cls.get_token()
        if not token:
            return {'ok': False, 'error': 'TELEGRAM_BOT_TOKEN no configurado'}

        url = f"https://api.telegram.org/bot{token}/deleteWebhook"
        payload = json.dumps({
            "drop_pending_updates": drop_pending_updates
        }).encode('utf-8')

        headers = {'Content-Type': 'application/json'}
        req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                res = json.loads(resp.read().decode('utf-8'))
                logger.info(f"[TelegramBotService] deleteWebhook resultado: {res}")
                return res
        except Exception as e:
            logger.error(f"[TelegramBotService] Error eliminando webhook: {e}")
            return {'ok': False, 'error': str(e)}

    @classmethod
    def procesar_mensaje(cls, chat_id, text, from_user=None, usuario_solicitante=None):
        """
        Procesa un mensaje recibido (sea por Webhook o por Polling).
        Responde al usuario en Telegram y actualiza el estado en la base de datos.
        """
        if not chat_id:
            return {'status': 'ignored', 'motivo': 'chat_id ausente'}

        text = (text or '').strip()
        str_chat_id = str(chat_id)
        first_name = (from_user or {}).get('first_name', '')

        # 1. Comando /start con token
        if text.startswith('/start'):
            partes = text.split(None, 1)
            token = partes[1].strip() if len(partes) > 1 else None

            if token:
                usuario = Usuario.objects.filter(telegram_token_vinculacion=token).first()
                if usuario:
                    usuario.telegram_chat_id = str_chat_id
                    usuario.telegram_vinculado = True
                    usuario.telegram_token_vinculacion = None
                    usuario.save()
                    AuditService.registrar_accion(usuario, 'TELEGRAM_VINCULADO', {'chat_id': str_chat_id})
                    
                    TelegramChannel.enviar_mensaje(
                        str_chat_id,
                        f"🎉 <b>¡Cuenta vinculada exitosamente!</b>\n\n"
                        f"Hola <b>{usuario.username}</b>, tu cuenta de Telegram ha sido vinculada al sistema <b>CEOS Clínico</b>.\n\n"
                        f"📱 A partir de ahora recibirás en este chat:\n"
                        f"• Alertas críticas de inventario y stock mínimo\n"
                        f"• Códigos de verificación y recuperación de contraseña\n"
                        f"• Respaldos automáticos de base de datos (Superadmin)\n\n"
                        f"<i>Ya puedes volver a la aplicación móvil.</i>"
                    )
                    return {'status': 'ok', 'mensaje': f'Usuario {usuario.username} vinculado con éxito'}
                else:
                    TelegramChannel.enviar_mensaje(
                        str_chat_id,
                        "⚠️ <b>Enlace inválido o expirado</b>\n\n"
                        "El código de vinculación no es válido o ya fue utilizado.\n"
                        "Por favor ingresa a la app móvil CEOS y genera un nuevo enlace."
                    )
                    return {'status': 'error', 'mensaje': 'Token no encontrado o ya vinculado'}
            else:
                # /start sin token
                usuario = Usuario.objects.filter(telegram_chat_id=str_chat_id).first()
                if usuario:
                    TelegramChannel.enviar_mensaje(
                        str_chat_id,
                        f"👋 <b>Hola {usuario.username}</b>\n\n"
                        f"Tu cuenta ya está vinculada a <b>CEOS Clínico</b>.\n"
                        f"Usa /estado para ver tus datos o /ayuda para ver los comandos disponibles."
                    )
                else:
                    # Fallback para desarrollo: si hay usuario_solicitante o sólo 1 usuario con token pendiente
                    if usuario_solicitante and not usuario_solicitante.telegram_vinculado:
                        usuario_target = usuario_solicitante
                    else:
                        pendientes = list(Usuario.objects.filter(telegram_vinculado=False, telegram_token_vinculacion__isnull=False))
                        usuario_target = pendientes[0] if len(pendientes) == 1 else None

                    if usuario_target:
                        usuario_target.telegram_chat_id = str_chat_id
                        usuario_target.telegram_vinculado = True
                        usuario_target.telegram_token_vinculacion = None
                        usuario_target.save()
                        AuditService.registrar_accion(usuario_target, 'TELEGRAM_VINCULADO', {'chat_id': str_chat_id})
                        TelegramChannel.enviar_mensaje(
                            str_chat_id,
                            f"🎉 <b>¡Cuenta vinculada exitosamente!</b>\n\n"
                            f"Hola <b>{usuario_target.username}</b>, tu cuenta ha sido vinculada al sistema <b>CEOS Clínico</b>."
                        )
                        return {'status': 'ok', 'mensaje': f'Usuario {usuario_target.username} vinculado por fallback'}

                    TelegramChannel.enviar_mensaje(
                        str_chat_id,
                        f"👋 <b>¡Bienvenido al Bot de CEOS Clínico!</b>\n\n"
                        f"Para recibir notificaciones del sistema, inicia sesión en la aplicación móvil y pulsa en <b>Vincular Telegram</b>."
                    )
                return {'status': 'ok'}

        # 2. Comando /estado
        if text in ['/estado', '/status']:
            usuario = Usuario.objects.filter(telegram_chat_id=str_chat_id).first()
            if usuario:
                roles_str = ", ".join([r.nombre for r in usuario.roles.all()]) if hasattr(usuario, 'roles') and usuario.roles.exists() else "Usuario"
                TelegramChannel.enviar_mensaje(
                    str_chat_id,
                    f"🛡️ <b>ESTADO DE VINCULACIÓN CEOS</b>\n\n"
                    f"👤 <b>Usuario:</b> {usuario.username}\n"
                    f"🏷️ <b>Rol:</b> {roles_str}\n"
                    f"📧 <b>Correo:</b> {getattr(usuario, 'correo_interno', 'No registrado')}\n"
                    f"✅ <b>Estado:</b> Vinculado y Activo"
                )
            else:
                TelegramChannel.enviar_mensaje(
                    str_chat_id,
                    "⚠️ <b>Sin vinculación</b>\n\nEste chat de Telegram no está vinculado a ninguna cuenta del sistema CEOS."
                )
            return {'status': 'ok'}

        # 3. Comando /ayuda
        if text in ['/ayuda', '/help']:
            TelegramChannel.enviar_mensaje(
                str_chat_id,
                "🤖 <b>Bot de Notificaciones CEOS Clínico</b>\n\n"
                "<b>Comandos disponibles:</b>\n"
                "• /start - Iniciar o reconectar cuenta\n"
                "• /estado - Ver tu información y estado de vinculación\n"
                "• /ayuda - Mostrar esta ayuda\n\n"
                "<i>Este bot despacha notificaciones automáticas autorizadas por el sistema.</i>"
            )
            return {'status': 'ok'}

        # 4. Cualquier otro mensaje de texto
        usuario = Usuario.objects.filter(telegram_chat_id=str_chat_id).first()
        if usuario:
            TelegramChannel.enviar_mensaje(
                str_chat_id,
                f"Hola {usuario.username}, he recibido tu mensaje. Este es un canal automatizado de notificaciones. Usa /estado o /ayuda si necesitas más información."
            )
        else:
            TelegramChannel.enviar_mensaje(
                str_chat_id,
                "👋 Hola, este bot es exclusivo para usuarios de <b>CEOS Clínico</b>. Para vincular tu cuenta, ingresa desde la aplicación móvil."
            )
        return {'status': 'ok'}

    @classmethod
    def procesar_updates_polling(cls, usuario_solicitante=None):
        token = cls.get_token()
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
            return {'error': data.get('description', 'Respuesta no OK de Telegram'), 'vinculados': 0}

        procesados = 0
        max_update_id = None

        for update in data.get('result', []):
            update_id = update.get('update_id')
            if max_update_id is None or update_id > max_update_id:
                max_update_id = update_id

            message = update.get('message', {})
            text = message.get('text', '').strip()
            chat_id = message.get('chat', {}).get('id')
            from_user = message.get('from', {})

            if chat_id:
                cls.procesar_mensaje(chat_id, text, from_user=from_user, usuario_solicitante=usuario_solicitante)
                procesados += 1

        if max_update_id is not None:
            confirm_url = f"https://api.telegram.org/bot{token}/getUpdates"
            payload = json.dumps({'offset': max_update_id + 1}).encode('utf-8')
            try:
                req2 = urllib.request.Request(confirm_url, data=payload, headers={'Content-Type': 'application/json'}, method='POST')
                urllib.request.urlopen(req2, timeout=5)
            except Exception:
                pass

        return {'updates_procesados': procesados, 'ok': True}
