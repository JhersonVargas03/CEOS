from rest_framework import serializers
from .models import ConfiguracionSistema, CanalMensajeria, NotificacionApp

class ConfiguracionSistemaSerializer(serializers.ModelSerializer):
    class Meta:
        model = ConfiguracionSistema
        fields = ['id', 'canal_mensajeria_activo', 'alertas_inventario_activas', 'actualizado_en', 'actualizado_por']

class CanalMensajeriaUpdateSerializer(serializers.Serializer):
    canal_mensajeria_activo = serializers.ChoiceField(choices=CanalMensajeria.choices)

class AlertasInventarioUpdateSerializer(serializers.Serializer):
    alertas_inventario_activas = serializers.BooleanField()

class NotificacionAppSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificacionApp
        fields = ['id', 'usuario', 'titulo', 'mensaje', 'leida', 'tipo', 'referencia_id', 'fecha_creacion']
        read_only_fields = ['id', 'usuario', 'fecha_creacion']
