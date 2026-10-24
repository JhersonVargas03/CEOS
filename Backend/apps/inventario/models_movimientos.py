from django.db import models
from django.conf import settings
from .models import Material
from .models_lotes import Lote


class MovimientoSalida(models.Model):
    """Registro general de salida de un material del inventario."""
    material = models.ForeignKey(
        Material,
        on_delete=models.CASCADE,
        related_name='movimientos_salida'
    )
    cantidad_total = models.PositiveIntegerField()
    motivo_destino = models.TextField(blank=True, default='')
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='salidas_registradas'
    )
    fecha_hora = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Movimiento de Salida'
        verbose_name_plural = 'Movimientos de Salida'
        ordering = ['-fecha_hora']
        indexes = [
            models.Index(fields=['material', 'fecha_hora']),
        ]

    def __str__(self):
        return f"Salida #{self.id} - {self.material.nombre} ({self.cantidad_total} unidades)"


class MovimientoSalidaLote(models.Model):
    """Detalle de qué cantidad se descontó de cada lote específico en una salida FEFO."""
    movimiento_salida = models.ForeignKey(
        MovimientoSalida,
        on_delete=models.CASCADE,
        related_name='detalles_lote'
    )
    lote = models.ForeignKey(
        Lote,
        on_delete=models.CASCADE,
        related_name='salidas_asociadas'
    )
    cantidad_descontada = models.PositiveIntegerField()

    class Meta:
        verbose_name = 'Detalle Salida Lote'
        verbose_name_plural = 'Detalles Salida Lotes'

    def __str__(self):
        return f"Salida #{self.movimiento_salida.id} -> Lote {self.lote.codigo_lote}: -{self.cantidad_descontada}"
