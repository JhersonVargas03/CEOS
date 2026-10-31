"""
Comando de gestión Django: run_telegram_bot
===========================================
Escucha mensajes del bot de Telegram en tiempo real mediante long-polling.
Ideal para desarrollo local donde no hay una URL pública para un webhook.

Uso:
    python manage.py run_telegram_bot              # Polling continuo (Ctrl+C para detener)
    python manage.py run_telegram_bot --once       # Procesa updates pendientes y sale
    python manage.py run_telegram_bot --interval 3 # Intervalo entre polls (segundos)
"""
import time
import signal
import json
import urllib.request
import logging

from django.core.management.base import BaseCommand
from django.conf import settings
from apps.usuarios.telegram_service import TelegramBotService

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Escucha mensajes de Telegram en tiempo real (long-polling). Solo para desarrollo local.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--interval',
            type=float,
            default=2.0,
            help='Intervalo en segundos entre cada poll a Telegram (defecto: 2).'
        )
        parser.add_argument(
            '--once',
            action='store_true',
            help='Procesar updates pendientes una sola vez y salir.'
        )
        parser.add_argument(
            '--timeout',
            type=int,
            default=30,
            help='Timeout de long-polling en Telegram getUpdates (defecto: 30s).'
        )

    def handle(self, *args, **options):
        token = TelegramBotService.get_token()
        if not token:
            self.stderr.write(self.style.ERROR(
                'TELEGRAM_BOT_TOKEN no configurado. Agrega el token en el .env y reinicia.'
            ))
            return

        intervalo = options['interval']
        solo_una_vez = options['once']
        long_timeout = options['timeout']

        # Verificar si hay webhook activo (si lo hay, no usar polling simultáneo)
        info = TelegramBotService.obtener_info_webhook()
        webhook_url = info.get('result', {}).get('url', '')
        if webhook_url:
            self.stdout.write(self.style.WARNING(
                f'⚠️  Hay un webhook activo: {webhook_url}\n'
                f'   Telegram no enviará updates por polling mientras el webhook esté registrado.\n'
                f'   Para usar polling local, elimina el webhook primero con:\n'
                f'   python manage.py run_telegram_bot --remove-webhook\n'
                f'   O ajusta TELEGRAM_WEBHOOK_URL en el .env.\n'
            ))

        # Banner de inicio
        bot_name = getattr(settings, 'TELEGRAM_BOT_NAME', 'Ceos_Clibot')
        self.stdout.write(self.style.SUCCESS(
            f'\n┌─────────────────────────────────────────────────┐\n'
            f'│   🤖  CEOS Telegram Bot — Modo Polling Local    │\n'
            f'│   Bot: @{bot_name:<40}│\n'
            f'│   Intervalo: {intervalo}s   Long-poll timeout: {long_timeout}s      │\n'
            f'│   Presiona Ctrl+C para detener                  │\n'
            f'└─────────────────────────────────────────────────┘\n'
        ))

        # Capturar Ctrl+C limpiamente
        self._running = True

        def _stop(sig, frame):
            self._running = False
            self.stdout.write(self.style.WARNING('\n⏹  Deteniendo bot de Telegram...'))

        signal.signal(signal.SIGINT, _stop)
        signal.signal(signal.SIGTERM, _stop)

        offset = None  # ID del último update procesado + 1

        while self._running:
            try:
                url = f"https://api.telegram.org/bot{token}/getUpdates"
                params = {'timeout': long_timeout, 'allowed_updates': ['message']}
                if offset is not None:
                    params['offset'] = offset

                encoded = urllib.parse.urlencode(params)
                full_url = f"{url}?{encoded}"
                req = urllib.request.Request(full_url, method='GET')

                with urllib.request.urlopen(req, timeout=long_timeout + 5) as resp:
                    data = json.loads(resp.read().decode('utf-8'))

                if not data.get('ok'):
                    self.stderr.write(self.style.ERROR(
                        f'❌ Telegram respondió: {data.get("description", "Error desconocido")}'
                    ))
                    time.sleep(intervalo * 3)
                    continue

                updates = data.get('result', [])
                if updates:
                    self.stdout.write(f'📨 {len(updates)} mensaje(s) recibido(s)')

                for update in updates:
                    update_id = update.get('update_id')
                    if offset is None or update_id >= offset:
                        offset = update_id + 1

                    message = update.get('message', {})
                    text = message.get('text', '').strip()
                    chat_id = message.get('chat', {}).get('id')
                    from_user = message.get('from', {})
                    username_tg = from_user.get('username', from_user.get('first_name', '?'))

                    self.stdout.write(
                        f'  💬 [{username_tg}({chat_id})] → {text[:60]}'
                    )

                    result = TelegramBotService.procesar_mensaje(
                        chat_id, text, from_user=from_user
                    )
                    self.stdout.write(
                        self.style.SUCCESS(f'     ✓ {result.get("status", "ok")}: {result.get("mensaje", "")}')
                    )

            except Exception as e:
                err = str(e)
                if 'timed out' in err.lower() or 'timeout' in err.lower():
                    # Timeout normal en long-polling — no es un error real
                    pass
                else:
                    self.stderr.write(self.style.ERROR(f'❌ Error polling: {e}'))
                    time.sleep(intervalo * 2)

            if solo_una_vez:
                break

            if self._running:
                time.sleep(intervalo)

        self.stdout.write(self.style.SUCCESS('✅ Bot de Telegram detenido correctamente.'))
