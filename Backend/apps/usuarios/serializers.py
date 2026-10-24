from rest_framework import serializers
from .models import Usuario, Rol, Permiso, UsuarioRol, RolPermiso, CodigoRecuperacion

class LoginSerializer(serializers.Serializer):
    identificador = serializers.CharField(required=True, trim_whitespace=True)
    password = serializers.CharField(required=True, write_only=True)

class PerfilUsuarioSerializer(serializers.ModelSerializer):
    roles = serializers.SerializerMethodField()
    permisos = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = [
            'id', 'username', 'correo_interno', 'nombre_completo', 'telefono', 'activo',
            'primer_login_completado', 'telegram_vinculado', 'telefono_verificado',
            'session_version', 'date_joined', 'roles', 'permisos'
        ]

    def get_roles(self, obj):
        return list(obj.roles.values_list('nombre', flat=True))

    def get_permisos(self, obj):
        from .models import obtener_permisos_efectivos
        return list(obtener_permisos_efectivos(obj))

class RolSerializer(serializers.ModelSerializer):
    permisos_codigos = serializers.SerializerMethodField()
    permisos = serializers.SerializerMethodField()

    class Meta:
        model = Rol
        fields = ['id', 'nombre', 'descripcion', 'es_superadmin', 'es_de_fabrica', 'permisos_codigos', 'permisos']

    def get_permisos_codigos(self, obj):
        return list(obj.permisos.values_list('codigo', flat=True))

    def get_permisos(self, obj):
        return list(obj.permisos.values_list('codigo', flat=True))

class RolCreateUpdateSerializer(serializers.Serializer):
    nombre = serializers.CharField(max_length=100, required=False)
    descripcion = serializers.CharField(required=False, allow_blank=True)
    permisos_ids = serializers.ListField(child=serializers.IntegerField(), required=False)
    permisos_codigos = serializers.ListField(child=serializers.CharField(), required=False)

class PermisoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Permiso
        fields = ['id', 'codigo', 'nombre', 'descripcion']

class UsuarioAdminSerializer(serializers.ModelSerializer):
    roles = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = [
            'id', 'username', 'correo_interno', 'nombre_completo', 'telefono', 'activo',
            'primer_login_completado', 'telegram_vinculado', 'telefono_verificado',
            'session_version', 'date_joined', 'roles'
        ]

    def get_roles(self, obj):
        return list(obj.roles.values_list('nombre', flat=True))

import re

def validar_y_normalizar_telefono_bolivia(value: str) -> str:
    """
    Valida y normaliza un número de teléfono de Bolivia (+591).
    Acepta 8 dígitos (celulares que comienzan con 6 o 7, fijos con 2, 3 o 4),
    con o sin prefijo '591' / '+591'.
    Retorna el número normalizado: '+591XXXXXXXX'.
    """
    if not value:
        return ""
    limpio = re.sub(r'[\s\-\(\)\.]', '', str(value))
    if limpio.startswith('+591'):
        limpio = limpio[4:]
    elif limpio.startswith('591'):
        limpio = limpio[3:]
    elif limpio.startswith('+'):
        raise serializers.ValidationError("El sistema solo admite números telefónicos de Bolivia (+591).")

    if not re.match(r'^[23467]\d{7}$', limpio):
        raise serializers.ValidationError(
            "El número debe ser un teléfono válido de Bolivia de 8 dígitos (ej. 71234567 o 22345678)."
        )
    return f"+591{limpio}"


class UsuarioAdminCreateSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    correo_interno = serializers.EmailField()
    nombre_completo = serializers.CharField(max_length=150, required=False, allow_blank=True, default='')
    telefono = serializers.CharField(max_length=30, required=False, allow_blank=True, default='')
    roles_ids = serializers.ListField(child=serializers.IntegerField(), required=False)

    def validate_telefono(self, value):
        if not value:
            return ""
        return validar_y_normalizar_telefono_bolivia(value)

class UsuarioAdminUpdateSerializer(serializers.Serializer):
    nombre_completo = serializers.CharField(max_length=150, required=False, allow_blank=True)
    telefono = serializers.CharField(max_length=30, required=False, allow_blank=True)
    roles_ids = serializers.ListField(child=serializers.IntegerField(), required=False)

    def validate_telefono(self, value):
        if not value:
            return ""
        return validar_y_normalizar_telefono_bolivia(value)


class PerfilUpdateSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=50, required=False, allow_blank=False)
    nombre_completo = serializers.CharField(max_length=150, required=False, allow_blank=True)
    telefono = serializers.CharField(max_length=30, required=False, allow_blank=True)
    password_actual = serializers.CharField(required=False, allow_blank=True, write_only=True)
    password_nueva = serializers.CharField(min_length=8, required=False, allow_blank=True, write_only=True)

    def validate_username(self, value):
        if not value:
            return ""
        norm = value.strip().lower()
        if len(norm) < 3:
            raise serializers.ValidationError('El nombre de usuario debe contener al menos 3 caracteres.')
        if len(norm) > 30:
            raise serializers.ValidationError('El nombre de usuario no puede exceder los 30 caracteres.')
        import re
        if not re.match(r'^[a-z0-9._]+$', norm):
            raise serializers.ValidationError('El nombre de usuario solo puede contener letras, números, puntos (.) o guiones bajos (_).')
        return norm

    def validate_telefono(self, value):
        if not value:
            return ""
        return validar_y_normalizar_telefono_bolivia(value)

    def validate(self, data):
        pwd_act = data.get('password_actual')
        pwd_nueva = data.get('password_nueva')
        if pwd_nueva and not pwd_act:
            raise serializers.ValidationError({
                'password_actual': 'Debe ingresar su contraseña actual para establecer una nueva contraseña.'
            })
        return data


# Recuperación de contraseña
class SolicitarRecuperacionSerializer(serializers.Serializer):
    identificador = serializers.CharField(required=True, trim_whitespace=True)

class VerificarCodigoRecuperacionSerializer(serializers.Serializer):
    identificador = serializers.CharField(required=True, trim_whitespace=True)
    codigo = serializers.CharField(max_length=6, required=True)

class CambiarPasswordRecuperacionSerializer(serializers.Serializer):
    identificador = serializers.CharField(required=True, trim_whitespace=True)
    codigo = serializers.CharField(max_length=6, required=True)
    nueva_password = serializers.CharField(min_length=8, required=True)
