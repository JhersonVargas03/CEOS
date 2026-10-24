from django.db import models
from django.conf import settings
from django.core.cache import cache

class CanalMensajeria(models.TextChoices):
    TELEGRAM = 'TELEGRAM', 'Telegram Bot'
    WHATSAPP = 'WHATSAPP', 'WhatsApp Gateway'
    AMBOS = 'AMBOS', 'Ambos Canales (Telegram + WhatsApp)'
    NINGUNO = 'NINGUNO', 'Sin Notificaciones Externas'

class ConfiguracionSistema(models.Model):
    canal_mensajeria_activo = models.CharField(
        max_length=20,
        choices=CanalMensajeria.choices,
        default=CanalMensajeria.TELEGRAM
    )
    alertas_inventario_activas = models.BooleanField(
        default=True,
        help_text="Indica si el job periódico de Celery envía alertas automáticas de stock bajo y vencimiento."
    )
    actualizado_en = models.DateTimeField(auto_now=True)
    actualizado_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    class Meta:
        verbose_name = 'Configuración del Sistema'
        verbose_name_plural = 'Configuraciones del Sistema'

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        cache.set('canal_mensajeria_activo', self.canal_mensajeria_activo, timeout=86400)
        cache.set('alertas_inventario_activas', self.alertas_inventario_activas, timeout=86400)

    @classmethod
    def obtener_canal_activo(cls):
        cached = cache.get('canal_mensajeria_activo')
        if cached is not None:
            return cached

        config = cls.objects.first()
        if not config:
            config = cls.objects.create(canal_mensajeria_activo=CanalMensajeria.TELEGRAM)

        cache.set('canal_mensajeria_activo', config.canal_mensajeria_activo, timeout=86400)
        return config.canal_mensajeria_activo

    @classmethod
    def obtener_alertas_inventario_activas(cls):
        cached = cache.get('alertas_inventario_activas')
        if cached is not None:
            return cached

        config = cls.objects.first()
        if not config:
            config = cls.objects.create(alertas_inventario_activas=True)

        cache.set('alertas_inventario_activas', config.alertas_inventario_activas, timeout=86400)
        return config.alertas_inventario_activas


class NotificacionApp(models.Model):
    """
    T-211.6: Modelo para notificaciones internas del sistema (In-App).
    """
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notificaciones_in_app'
    )
    titulo = models.CharField(max_length=200)
    mensaje = models.TextField()
    leida = models.BooleanField(default=False)
    tipo = models.CharField(max_length=50, default='general')
    referencia_id = models.IntegerField(null=True, blank=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-fecha_creacion']
        verbose_name = 'Notificación In-App'
        verbose_name_plural = 'Notificaciones In-App'
        indexes = [
            models.Index(fields=['usuario', 'leida']),
        ]

    def __str__(self):
        return f"Notificación in-app ({self.usuario.username}): {self.titulo}"
