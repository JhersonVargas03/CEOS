"""
Comando de gestión Django: setup_telegram_webhook
==================================================
Configura o elimina el webhook de Telegram para el bot de CEOS.
Diseñado para ejecutarse desde el entrypoint de producción (Render/Koyeb).

Uso:
    python manage.py setup_telegram_webhook                      # Configura con URL de Render
    python manage.py setup_telegram_webhook --url https://...    # Configura con URL personalizada
    python manage.py setup_telegram_webhook --status             # Ver estado actual
    python manage.py setup_telegram_webhook --remove             # Eliminar webhook (para polling local)
"""
import os
from django.core.management.base import BaseCommand
from apps.usuarios.telegram_service import TelegramBotService


class Command(BaseCommand):
    help = 'Configura o elimina el webhook de Telegram para el bot CEOS en producción.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--url',
            type=str,
            default=None,
            help='URL pública del webhook (ej. https://ceos-qb08.onrender.com/api/telegram/webhook). '
                 'Si no se especifica, usa TELEGRAM_WEBHOOK_URL del entorno o la URL de Render por defecto.'
        )
        parser.add_argument(
            '--remove',
            action='store_true',
            help='Eliminar el webhook activo (cambiar a modo polling).'
        )
        parser.add_argument(
            '--status',
            action='store_true',
            help='Mostrar el estado actual del webhook sin hacer cambios.'
        )
        parser.add_argument(
            '--drop-pending',
            action='store_true',
            help='Al eliminar el webhook, descartar también los updates pendientes.'
        )

    def handle(self, *args, **options):
        token = TelegramBotService.get_token()
        if not token:
            self.stderr.write(self.style.ERROR(
                '❌ TELEGRAM_BOT_TOKEN no configurado. Agrega el token en las variables de entorno.'
            ))
            return

        # ── Solo mostrar estado ──────────────────────────────────────────────
        if options['status']:
            self._mostrar_estado()
            return

        # ── Eliminar webhook ─────────────────────────────────────────────────
        if options['remove']:
            drop = options['drop_pending']
            self.stdout.write(f'🗑️  Eliminando webhook Telegram (drop_pending={drop})...')
            res = TelegramBotService.eliminar_webhook(drop_pending_updates=drop)
            if res.get('ok'):
                self.stdout.write(self.style.SUCCESS(
                    '✅ Webhook eliminado. El bot ahora solo responde a polling.\n'
                    '   Usa: python manage.py run_telegram_bot'
                ))
            else:
                self.stderr.write(self.style.ERROR(f'❌ Error: {res}'))
            return

        # ── Configurar webhook ───────────────────────────────────────────────
        webhook_url = (
            options.get('url') or
            os.environ.get('TELEGRAM_WEBHOOK_URL') or
            TelegramBotService.DEFAULT_WEBHOOK_URL
        )

        self.stdout.write(f'🔗 Configurando webhook de Telegram...')
        self.stdout.write(f'   URL: {webhook_url}')

        res = TelegramBotService.configurar_webhook(webhook_url)
        if res.get('ok'):
            self.stdout.write(self.style.SUCCESS(
                f'\n✅ Webhook configurado exitosamente.\n'
                f'   Descripción: {res.get("description", "OK")}\n'
                f'   Telegram enviará todos los mensajes entrantes a:\n'
                f'   {webhook_url}'
            ))
            self._mostrar_estado()
        else:
            self.stderr.write(self.style.ERROR(
                f'❌ Error configurando webhook:\n{res}'
            ))

    def _mostrar_estado(self):
        self.stdout.write('\n📡 Estado actual del webhook Telegram:')
        info = TelegramBotService.obtener_info_webhook()
        result = info.get('result', {})
        url = result.get('url', '(ninguno)')
        pendientes = result.get('pending_update_count', 0)
        ultimo_error = result.get('last_error_message', None)
        self.stdout.write(f'   Webhook URL: {url}')
        self.stdout.write(f'   Updates pendientes: {pendientes}')
        if ultimo_error:
            self.stdout.write(self.style.WARNING(f'   Último error: {ultimo_error}'))
        self.stdout.write('')
