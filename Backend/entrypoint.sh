#!/bin/sh
# entrypoint.sh — CEOS Backend
# Se ejecuta antes de Gunicorn en cada despliegue (Koyeb).
# Aplica migraciones, crea superusuario inicial si no existe,
# y recolecta estáticos.

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
python manage.py init_superuser

echo "──────────────────────────────────────────"
echo "  ✓ Inicialización completada"
echo "──────────────────────────────────────────"

# 4. Arrancar Gunicorn
exec "$@"
