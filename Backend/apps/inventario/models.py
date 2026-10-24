from django.db import models
from django.core.exceptions import ValidationError


class Area(models.Model):
    """Área física o funcional de la clínica donde se gestiona el inventario."""
    nombre = models.CharField(max_length=100, unique=True)
    descripcion = models.TextField(blank=True, default='')
    # T-304.1: Identificador de ícono Phosphor. Default 'package' garantiza fallback visual.
    icono = models.CharField(max_length=50, default='package')
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Área'
        verbose_name_plural = 'Áreas'
        ordering = ['nombre']
        indexes = [models.Index(fields=['nombre'])]

    def __str__(self):
        return self.nombre


class CategoriaMaterial(models.Model):
    """Categoría de clasificación de materiales (ej. Consumibles, Equipos, Medicamentos)."""
    nombre = models.CharField(max_length=100, unique=True)
    descripcion = models.TextField(blank=True, default='')
    # T-304.2: Identificador de ícono Phosphor. Default 'package' garantiza fallback visual.
    icono = models.CharField(max_length=50, default='package')
    # T-AJUSTE-BK.25: Relación opcional con Área para filtrar categorías por área clínica.
    area = models.ForeignKey(
        Area,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='categorias'
    )
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Categoría de Material'
        verbose_name_plural = 'Categorías de Material'
        ordering = ['nombre']
        indexes = [
            models.Index(fields=['nombre']),
            models.Index(fields=['area']),
        ]

    def __str__(self):
        return self.nombre


class Material(models.Model):
    """Material o insumo clínico perteneciente a un Área y Categoría."""
    nombre = models.CharField(max_length=200)
    descripcion = models.TextField(blank=True, default='')
    area = models.ForeignKey(
        Area,
        on_delete=models.PROTECT,
        related_name='materiales'
    )
    categoria = models.ForeignKey(
        CategoriaMaterial,
        on_delete=models.PROTECT,
        related_name='materiales'
    )
    unidad_medida = models.CharField(max_length=50, default='unidad')
    stock_minimo = models.PositiveIntegerField(default=0)
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Material'
        verbose_name_plural = 'Materiales'
        ordering = ['nombre']
        # T-203.3: Unicidad área + categoría + nombre
        unique_together = [('area', 'categoria', 'nombre')]
        indexes = [
            models.Index(fields=['nombre']),          # T-204.4
            models.Index(fields=['area', 'categoria']),
            models.Index(fields=['activo']),
        ]

    def __str__(self):
        return f"{self.nombre} ({self.area.nombre} / {self.categoria.nombre})"

    def stock_total_disponible(self):
        """T-203.5: Suma la cantidad_disponible de todos los lotes activos del material."""
        from apps.inventario.models_lotes import Lote
        return Lote.objects.filter(
            material=self,
            cantidad_disponible__gt=0
        ).aggregate(total=models.Sum('cantidad_disponible'))['total'] or 0

    def estado_stock(self):
        """Devuelve 'ok', 'bajo' o 'sin_stock' según el nivel de stock."""
        stock = self.stock_total_disponible()
        if stock == 0:
            return 'sin_stock'
        if stock <= self.stock_minimo:
            return 'bajo'
        return 'ok'


# Re-export all related models for Django model registry & migrations discovery
from .models_lotes import Lote  # noqa: F401, E402
from .models_movimientos import MovimientoSalida, MovimientoSalidaLote  # noqa: F401, E402
from .models_ajustes import AjusteInventario  # noqa: F401, E402
from .models_solicitudes import SolicitudMaterial  # noqa: F401, E402
from .models_reportes import ReporteGenerado  # noqa: F401, E402

