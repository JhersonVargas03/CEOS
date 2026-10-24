from django.db import models
from django.conf import settings


class RegistroAuditoria(models.Model):
    """
    Modelo append-only. Nunca debe ser editado ni eliminado.
    Cualquier intento de save() sobre un registro existente o delete() lanzará una excepción.
    """
    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='registros_auditoria'
    )
    accion = models.CharField(max_length=100, db_index=True)
    detalles = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    fecha_hora = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = 'Registro de Auditoría'
        verbose_name_plural = 'Registros de Auditoría'
        ordering = ['-fecha_hora']

    def __str__(self):
        usr = self.usuario.username if self.usuario else 'Sistema/Anónimo'
        return f"[{self.fecha_hora.strftime('%Y-%m-%d %H:%M:%S')}] {usr} - {self.accion}"

    def save(self, *args, **kwargs):
        """Bloquea cualquier UPDATE: solo se permite la creación inicial (INSERT)."""
        if self.pk is not None:
            raise PermissionError(
                "RegistroAuditoria es inmutable. No se permite modificar registros existentes de auditoría."
            )
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        """Bloquea completamente el borrado de registros de auditoría."""
        raise PermissionError(
            "RegistroAuditoria es inmutable. No se permite eliminar registros de auditoría."
        )
