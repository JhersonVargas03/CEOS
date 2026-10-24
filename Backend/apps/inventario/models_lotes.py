from django.db import models
from django.conf import settings
from django.utils import timezone
from .models import Material


class Lote(models.Model):
    """Lote de ingreso de un material específico."""
    material = models.ForeignKey(
        Material,
        on_delete=models.CASCADE,
        related_name='lotes'
    )
    codigo_lote = models.CharField(max_length=100)
    cantidad_ingresada = models.PositiveIntegerField()
    cantidad_disponible = models.PositiveIntegerField()
    costo = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    costo_registrado = models.BooleanField(default=False)
    fecha_ingreso = models.DateField(default=timezone.localdate)
    fecha_caducidad = models.DateField(null=True, blank=True)
    fecha_alerta_vencimiento = models.DateField(null=True, blank=True)
    usuario_ingreso = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='lotes_ingresados'
    )
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Lote'
        verbose_name_plural = 'Lotes'
        ordering = ['fecha_caducidad', '-creado_en']
        indexes = [
            models.Index(fields=['material', 'cantidad_disponible']),
            models.Index(fields=['codigo_lote']),
            models.Index(fields=['fecha_caducidad']),
        ]

    def __str__(self):
        return f"Lote {self.codigo_lote} - {self.material.nombre} ({self.cantidad_disponible}/{self.cantidad_ingresada})"

    @property
    def alerta_activa(self):
        """Calcula si la alerta de vencimiento está activa a la fecha actual."""
        hoy = timezone.now().date()
        if self.fecha_caducidad and hoy >= self.fecha_caducidad:
            return True
        if self.fecha_alerta_vencimiento and hoy >= self.fecha_alerta_vencimiento:
            return True
        return False
