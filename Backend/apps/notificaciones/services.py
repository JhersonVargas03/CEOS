import logging, urllib.request, urllib.parse, json
from django.conf import settings
from .models import ConfiguracionSistema, CanalMensajeria

logger = logging.getLogger(__name__)

class TelegramChannel:
    @staticmethod
    def enviar_mensaje(chat_id, mensaje):
        """Envía un mensaje por la Telegram Bot API usando urllib (sin dependencias externas pesadas)."""
        token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
        if not token or not chat_id:
            logger.warning(f"[TelegramChannel] Token o chat_id no provisto. chat_id={chat_id}")
            return False

        url = f"https://api.telegram.org/bot{token}/sendMessage"
        payload = json.dumps({
            "chat_id": chat_id,
            "text": mensaje,
            "parse_mode": "HTML"
        }).encode('utf-8')

        headers = {'Content-Type': 'application/json'}
        req = urllib.request.Request(url, data=payload, headers=headers, method='POST')

        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    logger.info(f"[TelegramChannel] Mensaje enviado exitosamente a {chat_id}")
                    return True
                else:
                    logger.error(f"[TelegramChannel] Error status {response.status} enviando a {chat_id}")
                    return False
        except Exception as e:
            logger.warning(f"[TelegramChannel] Fallback silencioso. No se pudo conectar a Telegram: {e}")
            return False

    @staticmethod
    def enviar_documento(chat_id, archivo_o_bytes, nombre_archivo, caption=None):
        """Envía un archivo como documento por la Telegram Bot API."""
        import os
        token = getattr(settings, 'TELEGRAM_BOT_TOKEN', '')
        if not token or not chat_id:
            logger.warning(f"[TelegramChannel] Token o chat_id no provisto para documento. chat_id={chat_id}")
            return False

        url = f"https://api.telegram.org/bot{token}/sendDocument"
        data = {"chat_id": chat_id}
        if caption:
            data["caption"] = caption[:1024]
            data["parse_mode"] = "HTML"

        try:
            import requests
            if isinstance(archivo_o_bytes, (bytes, bytearray)):
                files = {'document': (nombre_archivo, archivo_o_bytes)}
                resp = requests.post(url, data=data, files=files, timeout=45)
            elif isinstance(archivo_o_bytes, str) and os.path.exists(archivo_o_bytes):
                with open(archivo_o_bytes, 'rb') as f:
                    files = {'document': (nombre_archivo, f)}
                    resp = requests.post(url, data=data, files=files, timeout=45)
            else:
                logger.warning(f"[TelegramChannel] Archivo no válido o inexistente: {type(archivo_o_bytes)}")
                return False

            if resp.status_code == 200:
                logger.info(f"[TelegramChannel] Documento {nombre_archivo} enviado con éxito a {chat_id}")
                return True
            else:
                logger.error(f"[TelegramChannel] Error status {resp.status_code} enviando documento a {chat_id}: {resp.text}")
                return False
        except Exception as e:
            logger.warning(f"[TelegramChannel] Fallback silencioso. Error enviando documento a Telegram: {e}")
            return False


class WhatsAppChannel:
    @staticmethod
    def enviar_mensaje(telefono, mensaje):
        """Simulador/Stub de Gateway de WhatsApp (preparado para integración Twilio/Meta API)."""
        if not telefono:
            return False
        logger.info(f"[WhatsAppChannel] [MOCK] Mensaje enviado a {telefono}: {mensaje[:30]}...")
        return True


class NotificationService:
    @staticmethod
    def notificar_bloqueo_cuenta(usuario):
        mensaje = f"⚠️ <b>ALERTA DE SEGURIDAD CEOS</b> ⚠️\n\nEstimado/a {usuario.username},\nSu cuenta ha sido temporalmente bloqueada por acumular 5 intentos fallidos de inicio de sesión."
        NotificationService.enviar_mensaje(usuario, mensaje)

    @staticmethod
    def enviar_documento(usuario, archivo_o_bytes, nombre_archivo, caption=None):
        """Despacha un documento adjunto vía Telegram (o fallback a mensaje de texto si falla)."""
        if not usuario:
            return False

        canal_activo = ConfiguracionSistema.obtener_canal_activo()
        exito_telegram = False

        if canal_activo in [CanalMensajeria.TELEGRAM, CanalMensajeria.AMBOS]:
            if getattr(usuario, 'telegram_chat_id', None):
                exito_telegram = TelegramChannel.enviar_documento(
                    usuario.telegram_chat_id, archivo_o_bytes, nombre_archivo, caption
                )

        if not exito_telegram:
            logger.info(f"[NotificationService] Fallback: enviando mensaje de notificación a {usuario.username}")
            NotificationService.enviar_mensaje(usuario, caption or f"Documento generado: {nombre_archivo}")

        return exito_telegram

    @staticmethod
    def enviar_mensaje(usuario, mensaje):
        """Despacha la notificación según el canal activo configurado en el sistema."""
        if not usuario:
            return False

        canal_activo = ConfiguracionSistema.obtener_canal_activo()
        éxito_telegram = False
        éxito_whatsapp = False

        if canal_activo in [CanalMensajeria.TELEGRAM, CanalMensajeria.AMBOS]:
            if usuario.telegram_chat_id:
                éxito_telegram = TelegramChannel.enviar_mensaje(usuario.telegram_chat_id, mensaje)

        if canal_activo in [CanalMensajeria.WHATSAPP, CanalMensajeria.AMBOS] or (not éxito_telegram and usuario.telefono):
            if usuario.telefono:
                éxito_whatsapp = WhatsAppChannel.enviar_mensaje(usuario.telefono, mensaje)

        if canal_activo == CanalMensajeria.NINGUNO and not usuario.telefono:
            logger.info(f"[NotificationService] Canal NINGUNO activo. Notificación no enviada por canales externos.")
            return True

        return éxito_telegram or éxito_whatsapp or True  # Retorna True con fallback silencioso

    @staticmethod
    def obtener_deep_link_telegram(token_vinculacion):
        bot_name = getattr(settings, 'TELEGRAM_BOT_NAME', 'Ceos_Clibot')
        return f"https://t.me/{bot_name}?start={token_vinculacion}"

