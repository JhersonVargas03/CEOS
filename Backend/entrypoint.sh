#!/bin/sh
# entrypoint.sh — CEOS Backend
# Se ejecuta antes de Gunicorn en cada despliegue (Koyeb/Render).
# Aplica migraciones, crea superusuario inicial si no existe,
# recolecta estáticos y configura el webhook de Telegram.

set -e

echo "──────────────────────────────────────────"
echo "  CEOS Backend — Inicialización"
echo "──────────────────────────────────────────"

# 1. Migraciones de base de datos
echo "▶ Aplicando migraciones..."
python manage.py migrate --noinput

# 2. Recolectar estáticos (Whitenoise los sirve)
echo "▶ Recolectando archivos estáticos..."
python manage.py collectstatic --noinput --clear

# 3. Inicializar roles, permisos y superusuario
echo "▶ Inicializando roles, permisos y superusuario..."
python manage.py init_superuser || echo "⚠ Advertencia: init_superuser completado con avisos."

# 4. Configurar webhook de Telegram (solo en producción cuando TELEGRAM_BOT_TOKEN está definido)
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  echo "▶ Configurando webhook de Telegram..."
  python manage.py setup_telegram_webhook || echo "⚠ Advertencia: setup_telegram_webhook completado con avisos."
else
  echo "▶ TELEGRAM_BOT_TOKEN no configurado — omitiendo webhook."
fi

echo "──────────────────────────────────────────"
echo "  ✓ Inicialización completada"
echo "──────────────────────────────────────────"

# 5. Arrancar Gunicorn
exec "$@"
