from django.db import models
from django.conf import settings


class ReporteGenerado(models.Model):
    """
    T-REPORTE-HIST.1: Metadatos de cada reporte PDF generado.
    No almacena el PDF en disco; sólo guarda los parámetros necesarios
    para regenerar el documento idéntico en cualquier momento futuro.
    La inmutabilidad del historial de movimientos garantiza que el PDF
    regenerado siempre será igual al original.
    """
    generado_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reportes_generados',
    )
    # Rango de fechas usado al generar (opcional si es reporte histórico total)
    fecha_inicio = models.DateField(null=True, blank=True)
    fecha_fin = models.DateField(null=True, blank=True)

    # Filtros opcionales aplicados
    area = models.ForeignKey(
        'inventario.Area',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reportes',
    )
    categoria = models.ForeignKey(
        'inventario.CategoriaMaterial',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reportes',
    )
    usuario_filtrado = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='reportes_donde_aparece',
    )

    # Resumen de los totales al momento de generación (snapshot rápido)
    total_ingresos = models.PositiveIntegerField(default=0)
    total_salidas = models.PositiveIntegerField(default=0)
    total_ajustes = models.PositiveIntegerField(default=0)
    total_solicitudes = models.PositiveIntegerField(default=0)

    # ¿Se envió también por mensajería?
    enviado_por_mensajeria = models.BooleanField(default=False)

    # Nombre del archivo que se entregó al cliente
    nombre_archivo = models.CharField(max_length=200, blank=True, default='')

    generado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label = 'inventario'
        verbose_name = 'Reporte Generado'
        verbose_name_plural = 'Reportes Generados'
        ordering = ['-generado_en']
        indexes = [
            models.Index(fields=['generado_por', '-generado_en']),
            models.Index(fields=['fecha_inicio', 'fecha_fin']),
        ]

    def __str__(self):
        usr = self.generado_por.username if self.generado_por else 'Sistema'
        return f"Reporte {self.fecha_inicio}→{self.fecha_fin} por {usr} ({self.generado_en:%d/%m/%Y %H:%M})"

    @property
    def parametros_regeneracion(self):
        params = {}
        if self.fecha_inicio:
            params['fecha_inicio'] = str(self.fecha_inicio)
        if self.fecha_fin:
            params['fecha_fin'] = str(self.fecha_fin)
        if self.area_id:
            params['area_id'] = self.area_id
        if self.categoria_id:
            params['categoria_id'] = self.categoria_id
        if self.usuario_filtrado_id:
            params['usuario_id'] = self.usuario_filtrado_id
        return params
