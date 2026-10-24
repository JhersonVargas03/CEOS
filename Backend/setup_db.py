import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'apps'))

django.setup()

from django.core.management import call_command

if __name__ == '__main__':
    print("1. Generando migraciones pendientes...")
    call_command('makemigrations')
    print("2. Aplicando migraciones en base de datos...")
    call_command('migrate')
    print("3. Inicializando roles, permisos y superusuario inicial...")
    call_command('init_superuser')
    print("\n✓ Base de datos y superusuario inicial configurados al 100% exitosamente.")

