from django.db import models
from django.conf import settings


class RegistroBackup(models.Model):
    """Modelo para auditar y seguir el historial de respaldos de base de datos."""

    ORIGEN_CHOICES = (
        ('AUTOMATICO', 'Automático'),
        ('MANUAL', 'Manual'),
    )

    fecha_hora = models.DateTimeField(auto_now_add=True)
    nombre_archivo = models.CharField(max_length=255)
    tamano_bytes = models.BigIntegerField(default=0)
    exitoso = models.BooleanField(default=True)
    origen = models.CharField(max_length=20, choices=ORIGEN_CHOICES, default='AUTOMATICO')
    detalles_error = models.TextField(null=True, blank=True)
    usuario_solicitante = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='backups_solicitados'
    )
    tarea_id = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        verbose_name = 'Registro de Backup'
        verbose_name_plural = 'Registros de Backup'
        ordering = ['-fecha_hora']

    def __str__(self):
        estado = "EXITOSO" if self.exitoso else "FALLIDO"
        return f"Backup {self.nombre_archivo} [{self.origen}] - {estado} ({self.fecha_hora.strftime('%Y-%m-%d %H:%M')})"
