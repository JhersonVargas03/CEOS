from django.db import models
from django.conf import settings
from django.core.exceptions import ValidationError
from .models_lotes import Lote


class AjusteInventario(models.Model):
    """
    T-209.1 & T-210.3: Registro inmutable de ajuste manual de existencias de un lote.
    """
    lote = models.ForeignKey(
        Lote,
        on_delete=models.CASCADE,
        related_name='ajustes'
    )
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='ajustes_realizados'
    )
    cantidad_anterior = models.PositiveIntegerField()
    cantidad_nueva = models.PositiveIntegerField()
    motivo = models.TextField()
    fecha_hora = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Ajuste de Inventario'
        verbose_name_plural = 'Ajustes de Inventario'
        ordering = ['-fecha_hora']
        indexes = [
            models.Index(fields=['lote', 'fecha_hora']),
        ]

    def __str__(self):
        return f"Ajuste Lote {self.lote.codigo_lote}: {self.cantidad_anterior} -> {self.cantidad_nueva}"

    def save(self, *args, **kwargs):
        # T-210.3: Inmutabilidad — No permitir modificaciones post-creación
        if self.pk:
            raise ValidationError("Los registros de AjusteInventario son inmutables y no pueden editarse.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        # T-210.3: Inmutabilidad — No permitir eliminación
        raise ValidationError("Los registros de AjusteInventario no pueden ser eliminados.")
