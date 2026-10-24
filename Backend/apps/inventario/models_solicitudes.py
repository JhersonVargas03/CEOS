from django.db import models
from django.conf import settings
from .models import Material, Area


class EstadoSolicitud(models.TextChoices):
    PENDIENTE = 'pendiente', 'Pendiente'
    APROBADA = 'aprobada', 'Aprobada'
    RECHAZADA = 'rechazada', 'Rechazada'
    CANCELADA = 'cancelada', 'Cancelada'


class SolicitudMaterial(models.Model):
    """
    T-211.1: Modelo para registrar solicitudes de reposición de material por parte de personal autorizado.
    Permite solicitar materiales existentes en catálogo o nuevos materiales no registrados.
    """
    solicitante = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='solicitudes_creadas'
    )
    material = models.ForeignKey(
        Material,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='solicitudes'
    )
    nombre_material_nuevo = models.CharField(max_length=200, blank=True, default='')
    area = models.ForeignKey(
        Area,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='solicitudes'
    )
    unidad_medida = models.CharField(max_length=50, blank=True, default='unidades')
    cantidad_solicitada = models.PositiveIntegerField()
    motivo = models.CharField(max_length=500, default='sin_stock')
    estado = models.CharField(
        max_length=20,
        choices=EstadoSolicitud.choices,
        default=EstadoSolicitud.PENDIENTE
    )
    comentario_resolucion = models.TextField(blank=True, default='')
    resuelto_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='solicitudes_resueltas'
    )
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    fecha_resolucion = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Solicitud de Material'
        verbose_name_plural = 'Solicitudes de Material'
        ordering = ['-fecha_creacion']
        indexes = [
            models.Index(fields=['estado', 'fecha_creacion']),
            models.Index(fields=['solicitante', 'estado']),
        ]

    def __str__(self):
        nombre_mat = self.material.nombre if self.material else (f"{self.nombre_material_nuevo} (Nuevo)" if self.nombre_material_nuevo else "Material sin especificar")
        return f"Solicitud #{self.id} - {nombre_mat} ({self.cantidad_solicitada}) [{self.estado}]"
