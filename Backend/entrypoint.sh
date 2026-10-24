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

# 3. Crear superusuario inicial (solo si no existe)
echo "▶ Verificando superusuario..."
python manage.py shell -c "
from django.contrib.auth import get_user_model
import os
User = get_user_model()
username = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(
        username=username,
        email=os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@clinica.com'),
        password=os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'Admin1234!'),
    )
    print(f'Superusuario \"{username}\" creado exitosamente.')
else:
    print(f'Superusuario \"{username}\" ya existe, omitiendo.')
"

echo "──────────────────────────────────────────"
echo "  ✓ Inicialización completada"
echo "──────────────────────────────────────────"

# 4. Arrancar Gunicorn
exec "$@"
