class PermisoModel {
  final int id;
  final String codigo;
  final String nombre;
  final String descripcion;

  const PermisoModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion = '',
  });

  String get modulo {
    if (codigo.contains('usuario') || codigo.contains('rol') || codigo.contains('permiso')) {
      return 'Usuarios y Roles';
    }
    if (codigo.contains('inventario') || codigo.contains('entrada') || codigo.contains('salida') || codigo.contains('ajustar')) {
      return 'Inventario de Materiales';
    }
    if (codigo.contains('solicitar') || codigo.contains('solicitud')) {
      return 'Solicitudes de Material';
    }
    if (codigo.contains('reporte') || codigo.contains('dashboard')) {
      return 'Reportes y Dashboard';
    }
    if (codigo.contains('backup') || codigo.contains('sistema') || codigo.contains('config')) {
      return 'Sistema y Configuración';
    }
    return 'General';
  }

  factory PermisoModel.fromJson(Map<String, dynamic> json) {
    return PermisoModel(
      id: json['id'] as int? ?? 0,
      codigo: json['codigo'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
    );
  }
}

class RolModel {
  final int id;
  final String nombre;
  final String descripcion;
  final bool esSuperadmin;
  final bool esDeFabrica;
  final List<String> permisosCodigos;

  const RolModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.esSuperadmin = false,
    this.esDeFabrica = false,
    this.permisosCodigos = const [],
  });

  factory RolModel.fromJson(Map<String, dynamic> json) {
    final codigos = <String>[];
    if (json['permisos_codigos'] is List) {
      codigos.addAll((json['permisos_codigos'] as List).map((e) => e.toString()));
    } else if (json['permisos'] is List) {
      for (final p in json['permisos'] as List) {
        if (p is Map) {
          codigos.add(p['codigo']?.toString() ?? '');
        } else if (p is String) {
          codigos.add(p);
        }
      }
    }

    return RolModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      esSuperadmin: json['es_superadmin'] as bool? ?? false,
      esDeFabrica: json['es_de_fabrica'] as bool? ?? false,
      permisosCodigos: codigos,
    );
  }
}

class BackupHistorialModel {
  final int id;
  final String? tareaId;
  final String origen; // 'manual', 'automatico'
  final String estado; // 'exitoso', 'fallido', 'en_proceso'
  final int? tamanoBytes;
  final String creadoEn;
  final String? error;

  const BackupHistorialModel({
    required this.id,
    this.tareaId,
    required this.origen,
    required this.estado,
    this.tamanoBytes,
    required this.creadoEn,
    this.error,
  });

  bool get esExitoso => estado.toLowerCase() == 'exitoso';
  bool get esFallido => estado.toLowerCase() == 'fallido';
  bool get esEnProceso => estado.toLowerCase() == 'en_proceso';

  String get tamanoLegible {
    if (tamanoBytes == null || tamanoBytes == 0) return '0 KB';
    final kb = tamanoBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  factory BackupHistorialModel.fromJson(Map<String, dynamic> json) {
    // El backend retorna: exitoso (bool), fecha_hora, detalles_error, tamano_bytes (int|null)
    // Soporte adicional para campos legacy: estado, creado_en
    final esExitoso = json['exitoso'] as bool? ??
        (json['estado']?.toString().toLowerCase() == 'exitoso');
    final estado = esExitoso ? 'exitoso' : (json['estado'] as String? ?? 'fallido');

    // tamano_bytes puede venir como int, double o String
    int? tamano;
    final rawTam = json['tamano_bytes'];
    if (rawTam is int) {
      tamano = rawTam;
    } else if (rawTam is num) {
      tamano = rawTam.toInt();
    } else if (rawTam != null) {
      tamano = int.tryParse(rawTam.toString());
    }

    return BackupHistorialModel(
      id: json['id'] as int? ?? 0,
      tareaId: json['tarea_id'] as String? ?? json['id']?.toString(),
      origen: json['origen'] as String? ?? 'MANUAL',
      estado: estado,
      tamanoBytes: tamano,
      creadoEn: json['fecha_hora'] as String? ??
          json['creado_en'] as String? ??
          json['fecha'] as String? ?? '',
      error: json['detalles_error'] as String? ?? json['error'] as String?,
    );
  }
}

class ConfiguracionSistemaModel {
  final String canalActivo; // 'telegram', 'whatsapp'
  final bool alertasInventarioActivas;
  final bool twilioConfigurado;

  const ConfiguracionSistemaModel({
    required this.canalActivo,
    required this.alertasInventarioActivas,
    required this.twilioConfigurado,
  });

  factory ConfiguracionSistemaModel.fromJson(Map<String, dynamic> json) {
    return ConfiguracionSistemaModel(
      canalActivo: json['canal_activo'] as String? ?? json['canal_mensajeria'] as String? ?? 'telegram',
      alertasInventarioActivas: json['alertas_inventario_activas'] as bool? ??
          json['envio_alertas_activo'] as bool? ??
          true,
      twilioConfigurado: json['twilio_configurado'] as bool? ?? false,
    );
  }
}

class NotificacionModel {
  final int id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final String creadoEn;

  const NotificacionModel({
    required this.id,
    required this.titulo,
    required this.mensaje,
    this.tipo = 'info',
    this.leida = false,
    required this.creadoEn,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id: json['id'] as int? ?? 0,
      titulo: json['titulo'] as String? ?? 'Notificación',
      mensaje: json['mensaje'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'info',
      leida: json['leida'] as bool? ?? false,
      creadoEn: json['creado_en'] as String? ?? '',
    );
  }
}
