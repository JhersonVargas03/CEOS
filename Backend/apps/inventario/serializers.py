from django.utils import timezone
from rest_framework import serializers
from .models import Area, CategoriaMaterial, Material
from .models_lotes import Lote
from .constants import ICONOS_DISPONIBLES, es_icono_valido, normalizar_icono


class AreaSerializer(serializers.ModelSerializer):
    """T-304.6: Serializer de lectura de Área. Incluye campo `icono` y recuento de materiales activos."""
    cantidad_materiales = serializers.SerializerMethodField()

    class Meta:
        model = Area
        fields = ['id', 'nombre', 'descripcion', 'icono', 'activo', 'creado_en', 'cantidad_materiales']
        read_only_fields = ['id', 'creado_en', 'cantidad_materiales']

    def get_cantidad_materiales(self, obj):
        # Cuenta los materiales asociados al área que se encuentren activos
        if hasattr(obj, 'total_materiales_anotados'):
            return obj.total_materiales_anotados
        return obj.materiales.filter(activo=True).count()


class AreaCreateUpdateSerializer(serializers.Serializer):
    """T-304.6 / T-304.7: Serializer de escritura de Área. Valida `icono` contra el catálogo."""
    nombre = serializers.CharField(max_length=100)
    descripcion = serializers.CharField(required=False, allow_blank=True, default='')
    icono = serializers.CharField(max_length=50, required=False, default='package')

    def validate_icono(self, value):
        """T-304.7: Rechaza el request si el ícono no está en el catálogo válido."""
        normalizado = normalizar_icono(value)
        if not es_icono_valido(normalizado):
            raise serializers.ValidationError(
                f"El ícono '{value}' no es válido. Consulte GET /inventario/iconos-disponibles para ver el catálogo."
            )
        return normalizado


class CategoriaMaterialSerializer(serializers.ModelSerializer):
    """T-304.6 / T-AJUSTE-BK.25: Serializer de lectura de CategoríaMaterial. Incluye `icono`, `area_id` y `area_nombre`."""
    area_id = serializers.IntegerField(source='area.id', read_only=True, allow_null=True)
    area_nombre = serializers.CharField(source='area.nombre', read_only=True, allow_null=True)

    class Meta:
        model = CategoriaMaterial
        fields = ['id', 'nombre', 'descripcion', 'icono', 'area', 'area_id', 'area_nombre', 'activo', 'creado_en']
        read_only_fields = ['id', 'creado_en']


class CategoriaMaterialCreateUpdateSerializer(serializers.Serializer):
    """T-304.6 / T-304.7 / T-AJUSTE-BK.25: Serializer de escritura de CategoríaMaterial. Valida `icono` y acepta `area_id`."""
    nombre = serializers.CharField(max_length=100)
    descripcion = serializers.CharField(required=False, allow_blank=True, default='')
    icono = serializers.CharField(max_length=50, required=False, default='package')
    area_id = serializers.IntegerField(required=False, allow_null=True)

    def validate_icono(self, value):
        """T-304.7: Rechaza el request si el ícono no está en el catálogo válido."""
        normalizado = normalizar_icono(value)
        if not es_icono_valido(normalizado):
            raise serializers.ValidationError(
                f"El ícono '{value}' no es válido. Consulte GET /inventario/iconos-disponibles para ver el catálogo."
            )
        return normalizado



class MaterialSerializer(serializers.ModelSerializer):
    area_nombre = serializers.CharField(source='area.nombre', read_only=True)
    categoria_nombre = serializers.CharField(source='categoria.nombre', read_only=True)
    categoria_icono = serializers.CharField(source='categoria.icono', read_only=True)
    stock_disponible = serializers.SerializerMethodField()
    stock_total = serializers.SerializerMethodField()
    estado_stock = serializers.SerializerMethodField()

    class Meta:
        model = Material
        fields = [
            'id', 'nombre', 'descripcion', 'area', 'area_nombre',
            'categoria', 'categoria_nombre', 'categoria_icono', 'unidad_medida',
            'stock_minimo', 'activo', 'stock_disponible', 'stock_total', 'estado_stock',
            'creado_en', 'actualizado_en'
        ]
        read_only_fields = ['id', 'creado_en', 'actualizado_en']

    def get_stock_disponible(self, obj):
        return obj.stock_total_disponible()

    def get_stock_total(self, obj):
        return obj.stock_total_disponible()

    def get_estado_stock(self, obj):
        return obj.estado_stock()


class MaterialCreateSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=200)
    descripcion = serializers.CharField(required=False, allow_blank=True, default='')
    area_id = serializers.IntegerField()
    categoria_id = serializers.IntegerField()
    unidad_medida = serializers.CharField(max_length=50, required=False, default='unidad')
    stock_minimo = serializers.IntegerField(min_value=0, required=False, default=0)
    stock_inicial = serializers.IntegerField(min_value=0, required=False, default=0)
    cantidad_inicial = serializers.IntegerField(min_value=0, required=False, default=0)
    codigo_lote = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    fecha_caducidad = serializers.DateField(required=False, allow_null=True, default=None)
    costo_unitario = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True, default=None)


class MaterialUpdateSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=200, required=False)
    descripcion = serializers.CharField(required=False, allow_blank=True)
    unidad_medida = serializers.CharField(max_length=50, required=False)
    stock_minimo = serializers.IntegerField(min_value=0, required=False)
    activo = serializers.BooleanField(required=False)


# ─────────────────────────────────────────────────────────────────────
# Lotes (Épica 2.B)
# ─────────────────────────────────────────────────────────────────────

class LoteSerializer(serializers.ModelSerializer):
    material_nombre = serializers.CharField(source='material.nombre', read_only=True)
    alerta_activa = serializers.BooleanField(read_only=True)

    class Meta:
        model = Lote
        fields = [
            'id', 'material', 'material_nombre', 'codigo_lote',
            'cantidad_ingresada', 'cantidad_disponible',
            'costo', 'costo_registrado', 'fecha_ingreso',
            'fecha_caducidad', 'fecha_alerta_vencimiento',
            'usuario_ingreso', 'alerta_activa', 'creado_en'
        ]
        read_only_fields = ['id', 'cantidad_disponible', 'costo_registrado', 'alerta_activa', 'creado_en']


class LoteCreateSerializer(serializers.Serializer):
    material_id = serializers.IntegerField(required=False)
    material = serializers.IntegerField(required=False)
    codigo_lote = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    numero_lote = serializers.CharField(max_length=100, required=False, allow_blank=True, default='')
    cantidad_ingresada = serializers.IntegerField(min_value=1, required=False)
    cantidad = serializers.IntegerField(min_value=1, required=False)
    costo = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True, default=None)
    costo_unitario = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True, default=None)
    fecha_ingreso = serializers.DateField(required=False)
    fecha_caducidad = serializers.DateField(required=False, allow_null=True, default=None)
    fecha_alerta_vencimiento = serializers.DateField(required=False, allow_null=True, default=None)
    fecha_alerta = serializers.DateField(required=False, allow_null=True, default=None)

    def validate(self, data):
        # Compatibilidad bidireccional de nombres de campos
        if not data.get('material_id') and data.get('material'):
            data['material_id'] = data['material']
        if not data.get('material_id'):
            raise serializers.ValidationError({'material_id': 'Este campo es requerido.'})

        if not data.get('cantidad_ingresada') and data.get('cantidad'):
            data['cantidad_ingresada'] = data['cantidad']
        if not data.get('cantidad_ingresada'):
            raise serializers.ValidationError({'cantidad_ingresada': 'Este campo es requerido.'})

        if data.get('costo') is None and data.get('costo_unitario') is not None:
            data['costo'] = data['costo_unitario']

        if not data.get('fecha_alerta_vencimiento') and data.get('fecha_alerta'):
            data['fecha_alerta_vencimiento'] = data['fecha_alerta']

        codigo = data.get('codigo_lote') or data.get('numero_lote') or ''
        codigo = str(codigo).strip()
        if not codigo:
            codigo = 'Lote General'
        data['codigo_lote'] = codigo

        fecha_ingreso = data.get('fecha_ingreso')
        fecha_caducidad = data.get('fecha_caducidad')
        fecha_alerta = data.get('fecha_alerta_vencimiento')

        if fecha_ingreso and fecha_caducidad and fecha_caducidad < fecha_ingreso:
            raise serializers.ValidationError({
                'fecha_caducidad': 'La fecha de caducidad no puede ser anterior a la fecha de ingreso.'
            })

        if fecha_alerta and fecha_caducidad and fecha_alerta > fecha_caducidad:
            raise serializers.ValidationError({
                'fecha_alerta_vencimiento': 'La fecha de alerta de vencimiento debe ser anterior o igual a la fecha de caducidad.'
            })

        return data


# ─────────────────────────────────────────────────────────────────────
# Salidas de Material (Épica 2.C)
# ─────────────────────────────────────────────────────────────────────

class MovimientoSalidaLoteSerializer(serializers.ModelSerializer):
    lote_codigo = serializers.CharField(source='lote.codigo_lote', read_only=True)

    class Meta:
        from .models_movimientos import MovimientoSalidaLote
        model = MovimientoSalidaLote
        fields = ['id', 'lote', 'lote_codigo', 'cantidad_descontada']


class MovimientoSalidaSerializer(serializers.ModelSerializer):
    material_nombre = serializers.CharField(source='material.nombre', read_only=True)
    detalles_lote = MovimientoSalidaLoteSerializer(many=True, read_only=True)

    class Meta:
        from .models_movimientos import MovimientoSalida
        model = MovimientoSalida
        fields = [
            'id', 'material', 'material_nombre', 'cantidad_total',
            'motivo_destino', 'usuario', 'fecha_hora', 'detalles_lote'
        ]
        read_only_fields = ['id', 'fecha_hora', 'detalles_lote']


class SalidaCreateSerializer(serializers.Serializer):
    material_id = serializers.IntegerField(required=False)
    material = serializers.IntegerField(required=False)
    cantidad = serializers.IntegerField(min_value=1)
    motivo_destino = serializers.CharField(required=False, allow_blank=True, default='')
    motivo = serializers.CharField(required=False, allow_blank=True, default='')

    def validate(self, data):
        if not data.get('material_id') and data.get('material'):
            data['material_id'] = data['material']
        if not data.get('material_id'):
            raise serializers.ValidationError({'material_id': 'Este campo es requerido.'})
        if not data.get('motivo_destino') and data.get('motivo'):
            data['motivo_destino'] = data['motivo']
        return data


# ─────────────────────────────────────────────────────────────────────
# Ajustes de Inventario (Épica 2.D)
# ─────────────────────────────────────────────────────────────────────

class AjusteInventarioSerializer(serializers.ModelSerializer):
    lote_codigo = serializers.CharField(source='lote.codigo_lote', read_only=True)
    material_nombre = serializers.CharField(source='lote.material.nombre', read_only=True)
    usuario_username = serializers.CharField(source='usuario.username', read_only=True)

    class Meta:
        from .models_ajustes import AjusteInventario
        model = AjusteInventario
        fields = [
            'id', 'lote', 'lote_codigo', 'material_nombre',
            'usuario', 'usuario_username', 'cantidad_anterior',
            'cantidad_nueva', 'motivo', 'fecha_hora'
        ]
        read_only_fields = ['id', 'cantidad_anterior', 'fecha_hora']


class AjusteCreateSerializer(serializers.Serializer):
    lote_id = serializers.IntegerField(required=False)
    lote = serializers.IntegerField(required=False)
    material_id = serializers.IntegerField(required=False)
    material = serializers.IntegerField(required=False)
    cantidad_nueva = serializers.IntegerField(min_value=0)
    motivo = serializers.CharField(max_length=500)

    def validate_motivo(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("El motivo del ajuste es obligatorio y no puede quedar vacío.")
        return value.strip()

    def validate(self, data):
        if not data.get('lote_id') and data.get('lote'):
            data['lote_id'] = data['lote']
        if not data.get('material_id') and data.get('material'):
            data['material_id'] = data['material']
        if not data.get('lote_id') and not data.get('material_id'):
            raise serializers.ValidationError({'lote_id': 'Debe especificar el lote_id o material_id.'})
        return data


# ─────────────────────────────────────────────────────────────────────
# Solicitudes de Material (Épica 2.E)
# ─────────────────────────────────────────────────────────────────────

class SolicitudMaterialSerializer(serializers.ModelSerializer):
    solicitante_username = serializers.CharField(source='solicitante.username', read_only=True)
    material_nombre = serializers.SerializerMethodField()
    area_nombre = serializers.SerializerMethodField()
    resuelto_por_username = serializers.CharField(source='resuelto_por.username', read_only=True, default=None)

    class Meta:
        from .models_solicitudes import SolicitudMaterial
        model = SolicitudMaterial
        fields = [
            'id', 'solicitante', 'solicitante_username',
            'material', 'material_nombre', 'nombre_material_nuevo',
            'area', 'area_nombre', 'unidad_medida', 'cantidad_solicitada',
            'motivo', 'estado', 'comentario_resolucion',
            'resuelto_por', 'resuelto_por_username',
            'fecha_creacion', 'fecha_resolucion'
        ]
        read_only_fields = [
            'id', 'solicitante', 'estado', 'comentario_resolucion',
            'resuelto_por', 'fecha_creacion', 'fecha_resolucion'
        ]

    def get_material_nombre(self, obj):
        if obj.material:
            return obj.material.nombre
        return obj.nombre_material_nuevo or 'Material nuevo'

    def get_area_nombre(self, obj):
        if obj.material and obj.material.area:
            return obj.material.area.nombre
        if obj.area:
            return obj.area.nombre
        return ''


class SolicitudCreateSerializer(serializers.Serializer):
    material_id = serializers.IntegerField(required=False, allow_null=True)
    nombre_material_nuevo = serializers.CharField(max_length=200, required=False, allow_blank=True, default='')
    area_id = serializers.IntegerField(required=False, allow_null=True)
    unidad_medida = serializers.CharField(max_length=50, required=False, allow_blank=True, default='unidades')
    cantidad_solicitada = serializers.IntegerField(min_value=1)
    motivo = serializers.CharField(max_length=500, required=False, allow_blank=True, default='')

    def validate(self, data):
        material_id = data.get('material_id')
        nombre_nuevo = (data.get('nombre_material_nuevo') or '').strip()

        if not material_id and not nombre_nuevo:
            raise serializers.ValidationError({
                'material_id': 'Debe seleccionar un material existente o ingresar el nombre del nuevo material a solicitar.'
            })
        return data


class SolicitudUpdateSerializer(serializers.Serializer):
    cantidad_solicitada = serializers.IntegerField(min_value=1, required=False)
    motivo = serializers.CharField(max_length=500, required=False, allow_blank=True)


class SolicitudResolverSerializer(serializers.Serializer):
    accion = serializers.ChoiceField(choices=['aprobar', 'rechazar'])
    comentario = serializers.CharField(max_length=500, required=False, allow_blank=True, default='')
    comentario_resolucion = serializers.CharField(max_length=500, required=False, allow_blank=True, default='')

    def validate(self, data):
        accion = data.get('accion')
        comentario = (data.get('comentario') or data.get('comentario_resolucion') or '').strip()

        if accion == 'rechazar' and not comentario:
            raise serializers.ValidationError({
                'comentario': 'El comentario de resolución es obligatorio al rechazar una solicitud.'
            })

        data['comentario'] = comentario
        return data




