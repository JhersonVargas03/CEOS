from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
from django.core.cache import cache
from datetime import timedelta
import secrets, string

PERMISOS_MODO_CONGELADO = ["ver_mi_historial", "ver_mis_reportes"]

class Permiso(models.Model):
    codigo = models.CharField(max_length=100, unique=True, db_index=True)
    nombre = models.CharField(max_length=150)
    descripcion = models.TextField(blank=True, default='')

    class Meta:
        verbose_name = 'Permiso'
        verbose_name_plural = 'Permisos'

    def __str__(self):
        return f"{self.nombre} ({self.codigo})"

class Rol(models.Model):
    nombre = models.CharField(max_length=100, unique=True)
    descripcion = models.TextField(blank=True, default='')
    es_superadmin = models.BooleanField(default=False)
    es_de_fabrica = models.BooleanField(default=False)
    permisos = models.ManyToManyField(Permiso, through='RolPermiso', related_name='roles')

    class Meta:
        verbose_name = 'Rol'
        verbose_name_plural = 'Roles'

    def __str__(self):
        return self.nombre

class RolPermiso(models.Model):
    rol = models.ForeignKey(Rol, on_delete=models.CASCADE)
    permiso = models.ForeignKey(Permiso, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('rol', 'permiso')

class UsuarioManager(BaseUserManager):
    def create_user(self, username, correo_interno, password=None, **extra_fields):
        if not username:
            raise ValueError('El nombre de usuario es obligatorio')
        if not correo_interno:
            raise ValueError('El correo interno es obligatorio')

        username = username.strip().lower()
        correo_interno = self.normalize_email(correo_interno).strip().lower()

        user = self.model(
            username=username,
            correo_interno=correo_interno,
            **extra_fields
        )
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, username, correo_interno, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('activo', True)
        extra_fields.setdefault('primer_login_completado', True)

        user = self.create_user(username, correo_interno, password, **extra_fields)
        
        rol_superadmin = Rol.objects.filter(es_superadmin=True).first()
        if rol_superadmin:
            UsuarioRol.objects.get_or_create(usuario=user, rol=rol_superadmin)

        return user

class Usuario(AbstractBaseUser, PermissionsMixin):
    username = models.CharField(max_length=150, unique=True, db_index=True)
    correo_interno = models.EmailField(max_length=254, unique=True, db_index=True)
    nombre_completo = models.CharField(max_length=150, blank=True, default='')
    telefono = models.CharField(max_length=30, blank=True, default='')
    activo = models.BooleanField(default=True)
    intentos_fallidos = models.IntegerField(default=0)
    bloqueado_hasta = models.DateTimeField(null=True, blank=True)
    session_version = models.IntegerField(default=1)
    primer_login_completado = models.BooleanField(default=True)
    
    # Vinculación Telegram y OTP Teléfono
    telegram_chat_id = models.CharField(max_length=50, blank=True, null=True)
    telegram_vinculado = models.BooleanField(default=False)
    telegram_token_vinculacion = models.CharField(max_length=64, blank=True, null=True)
    telefono_verificado = models.BooleanField(default=False)
    otp_telefono_codigo = models.CharField(max_length=6, blank=True, null=True)
    otp_telefono_expiracion = models.DateTimeField(null=True, blank=True)

    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    roles = models.ManyToManyField(Rol, through='UsuarioRol', related_name='usuarios')

    objects = UsuarioManager()

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['correo_interno']

    class Meta:
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    def save(self, *args, **kwargs):
        if self.username:
            self.username = self.username.strip().lower()
        if self.correo_interno:
            self.correo_interno = self.correo_interno.strip().lower()
        
        if self.pk:
            viejo_usuario = Usuario.objects.filter(pk=self.pk).first()
            if viejo_usuario and viejo_usuario.activo != self.activo:
                invalidar_cache_permisos(self)

        super().save(*args, **kwargs)

    def esta_bloqueado(self):
        if self.bloqueado_hasta and timezone.now() < self.bloqueado_hasta:
            return True
        if self.bloqueado_hasta and timezone.now() >= self.bloqueado_hasta:
            self.bloqueado_hasta = None
            self.intentos_fallidos = 0
            self.save(update_fields=['bloqueado_hasta', 'intentos_fallidos'])
            return False
        return False

    def registrar_intento_fallido(self):
        self.intentos_fallidos += 1
        se_bloqueo = False
        if self.intentos_fallidos >= 5:
            self.bloqueado_hasta = timezone.now() + timedelta(minutes=15)
            se_bloqueo = True
        self.save(update_fields=['intentos_fallidos', 'bloqueado_hasta'])
        return se_bloqueo

    def resetear_intentos(self):
        if self.intentos_fallidos > 0 or self.bloqueado_hasta is not None:
            self.intentos_fallidos = 0
            self.bloqueado_hasta = None
            self.save(update_fields=['intentos_fallidos', 'bloqueado_hasta'])

    def incrementar_session_version(self):
        self.session_version += 1
        self.save(update_fields=['session_version'])
        invalidar_cache_permisos(self)
        return self.session_version

    def generar_token_telegram(self):
        token = secrets.token_urlsafe(16)
        self.telegram_token_vinculacion = token
        self.save(update_fields=['telegram_token_vinculacion'])
        return token

    @property
    def es_superadmin(self):
        return bool(self.is_superuser or (self.pk and self.roles.filter(es_superadmin=True).exists()))

    def generar_otp_telefono(self):
        digits = ''.join(secrets.choice(string.digits) for _ in range(6))
        self.otp_telefono_codigo = digits
        self.otp_telefono_expiracion = timezone.now() + timedelta(minutes=10)
        self.save(update_fields=['otp_telefono_codigo', 'otp_telefono_expiracion'])
        return digits

    def __str__(self):
        return f"{self.username} ({self.correo_interno})"

class UsuarioRol(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='usuario_roles')
    rol = models.ForeignKey(Rol, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('usuario', 'rol')

class CodigoRecuperacion(models.Model):
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='codigos_recuperacion')
    codigo = models.CharField(max_length=6, db_index=True)
    expiracion = models.DateTimeField(db_index=True)
    usado = models.BooleanField(default=False)
    intentos_fallidos = models.IntegerField(default=0)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Código de Recuperación'
        verbose_name_plural = 'Códigos de Recuperación'
        ordering = ['-creado_en']

    def esta_vigente(self):
        return not self.usado and self.intentos_fallidos < 3 and timezone.now() < self.expiracion

    def registrar_intento_fallido(self):
        self.intentos_fallidos += 1
        if self.intentos_fallidos >= 3:
            self.usado = True
        self.save(update_fields=['intentos_fallidos', 'usado'])


def obtener_permisos_efectivos(usuario):
    if not usuario or not usuario.pk:
        return set()

    if not usuario.activo:
        return set(PERMISOS_MODO_CONGELADO)

    cache_key = f"permisos_efectivos_user_{usuario.id}"
    permisos_cached = cache.get(cache_key)
    if permisos_cached is not None:
        return set(permisos_cached)

    es_superadmin = usuario.is_superuser or usuario.roles.filter(es_superadmin=True).exists()
    if es_superadmin:
        permisos_set = set(Permiso.objects.values_list('codigo', flat=True))
    else:
        permisos_set = set(
            Permiso.objects.filter(roles__usuarios=usuario).values_list('codigo', flat=True)
        )

    cache.set(cache_key, list(permisos_set), timeout=3600)
    return permisos_set


def invalidar_cache_permisos(usuario):
    if usuario and usuario.pk:
        cache.delete(f"permisos_efectivos_user_{usuario.id}")
