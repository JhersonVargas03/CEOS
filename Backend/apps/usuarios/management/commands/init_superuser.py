import os
from django.core.management.base import BaseCommand
from django.conf import settings
from apps.usuarios.models import Usuario, Rol, UsuarioRol
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos


class Command(BaseCommand):
    help = 'Inicializa los roles/permisos base y crea el superusuario inicial desde variables de entorno (.env).'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, help='Username del superusuario')
        parser.add_argument('--email', type=str, help='Correo interno del superusuario')
        parser.add_argument('--password', type=str, help='Contraseña del superusuario')

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("1. Cargando roles y permisos del sistema (Seeds)..."))
        cargar_seeds_roles_y_permisos()
        self.stdout.write(self.style.SUCCESS("✓ Roles y permisos inicializados correctamente."))

        username = options.get('username') or os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
        email = options.get('email') or os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@clinica.com')
        password = options.get('password') or os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'Admin1234!')

        username = username.strip().lower()
        email = email.strip().lower()

        self.stdout.write(self.style.NOTICE(f"2. Configurando superusuario '{username}' ({email})..."))

        usuario = Usuario.objects.filter(username__iexact=username).first()
        if not usuario:
            usuario = Usuario.objects.filter(correo_interno__iexact=email).first()

        rol_superadmin = Rol.objects.filter(es_superadmin=True).first()

        if usuario:
            usuario.username = username
            usuario.correo_interno = email
            usuario.set_password(password)
            usuario.activo = True
            usuario.primer_login_completado = True
            usuario.is_staff = True
            usuario.is_superuser = True
            usuario.intentos_fallidos = 0
            usuario.bloqueado_hasta = None
            usuario.save()
            self.stdout.write(self.style.SUCCESS(f"✓ Superusuario '{username}' ({email}) actualizado exitosamente."))
        else:
            try:
                usuario = Usuario.objects.create_superuser(
                    username=username,
                    correo_interno=email,
                    password=password,
                    telefono='+59170000000',
                    primer_login_completado=True
                )
                self.stdout.write(self.style.SUCCESS(f"✓ Superusuario '{username}' creado exitosamente."))
            except Exception as e:
                self.stdout.write(self.style.WARNING(f"⚠ Aviso al crear superusuario: {e}"))
                usuario = Usuario.objects.filter(correo_interno__iexact=email).first()

        if rol_superadmin:
            UsuarioRol.objects.get_or_create(usuario=usuario, rol=rol_superadmin)
            self.stdout.write(self.style.SUCCESS(f"✓ Rol '{rol_superadmin.nombre}' asignado correctamente al superusuario."))

        self.stdout.write("\n" + "="*55)
        self.stdout.write(self.style.SUCCESS(" Credenciales de acceso disponibles:"))
        self.stdout.write(f"  - Username / Identificador: {username}")
        self.stdout.write(f"  - Correo electrónico:     {email}")
        self.stdout.write(f"  - Contraseña:             {password}")
        self.stdout.write("="*55 + "\n")
