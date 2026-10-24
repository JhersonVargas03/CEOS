class AreaModel {
  final int id;
  final String nombre;
  final String descripcion;
  final String icono;
  final int cantidadMateriales;

  const AreaModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.icono = 'package',
    this.cantidadMateriales = 0,
  });

  bool get esOdontologia => nombre.toLowerCase().contains('odon');
  bool get esEstetica => nombre.toLowerCase().contains('est');

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      icono: json['icono'] as String? ?? 'package',
      cantidadMateriales: json['cantidad_materiales'] as int? ??
          json['total_materiales'] as int? ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'icono': icono,
      };
}

class CategoriaModel {
  final int id;
  final String nombre;
  final String descripcion;
  final String icono;
  final int? areaId;

  const CategoriaModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.icono = 'package',
    this.areaId,
  });

  factory CategoriaModel.fromJson(Map<String, dynamic> json) {
    return CategoriaModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      icono: json['icono'] as String? ?? 'package',
      areaId: json['area_id'] as int? ?? json['area'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'icono': icono,
        if (areaId != null) 'area_id': areaId,
      };
}

enum EstadoRibbon { normal, advertencia, critico }

class MaterialModel {
  final int id;
  final String nombre;
  final int areaId;
  final String areaNombre;
  final int categoriaId;
  final String categoriaNombre;
  final String categoriaIcono;
  final int stockTotal;
  final int stockMinimo;
  final int diasAlertaCaducidad;
  final String? fechaCaducidadProxima;
  final String unidadMedida;
  final String? icono;

  const MaterialModel({
    required this.id,
    required this.nombre,
    required this.areaId,
    this.areaNombre = '',
    required this.categoriaId,
    this.categoriaNombre = '',
    this.categoriaIcono = 'package',
    this.stockTotal = 0,
    this.stockMinimo = 5,
    this.diasAlertaCaducidad = 30,
    this.fechaCaducidadProxima,
    this.unidadMedida = 'unidades',
    this.icono,
  });

  EstadoRibbon get estadoRibbon {
    if (stockTotal <= 0 || stockTotal < stockMinimo) {
      return EstadoRibbon.critico;
    }
    // Check if near expiration if date provided
    if (fechaCaducidadProxima != null) {
      try {
        final exp = DateTime.parse(fechaCaducidadProxima!);
        final now = DateTime.now();
        final diff = exp.difference(now).inDays;
        if (diff <= diasAlertaCaducidad) {
          return EstadoRibbon.advertencia;
        }
      } catch (_) {}
    }
    return EstadoRibbon.normal;
  }

  bool get esCritico => stockTotal <= 0 || stockTotal <= (stockMinimo * 0.2).ceil();
  bool get esBajo => stockTotal > (stockMinimo * 0.2).ceil() && stockTotal < stockMinimo;
  bool get esAdvertencia => estadoRibbon == EstadoRibbon.advertencia;

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    final catData = json['categoria_detalle'] ?? json['categoria_data'] ?? (json['categoria'] is Map ? json['categoria'] : null);
    final areaData = json['area_detalle'] ?? json['area_data'] ?? (json['area'] is Map ? json['area'] : null);

    final rawStock = json['stock_disponible'] ?? json['stock_total'] ?? json['stock'] ?? json['cantidad_disponible'];
    final stockTotal = rawStock is num ? rawStock.toInt() : (int.tryParse(rawStock?.toString() ?? '') ?? 0);

    final rawStockMin = json['stock_minimo'];
    final stockMinimo = rawStockMin is num ? rawStockMin.toInt() : (int.tryParse(rawStockMin?.toString() ?? '') ?? 5);

    int parsedAreaId = 0;
    if (json['area'] is int) {
      parsedAreaId = json['area'] as int;
    } else if (json['area_id'] is int) {
      parsedAreaId = json['area_id'] as int;
    } else if (areaData is Map && areaData['id'] is int) {
      parsedAreaId = areaData['id'] as int;
    }

    String parsedAreaNombre = json['area_nombre'] as String? ??
        (areaData is Map ? areaData['nombre'] as String? ?? '' : '');

    int parsedCategoriaId = 0;
    if (json['categoria'] is int) {
      parsedCategoriaId = json['categoria'] as int;
    } else if (json['categoria_id'] is int) {
      parsedCategoriaId = json['categoria_id'] as int;
    } else if (catData is Map && catData['id'] is int) {
      parsedCategoriaId = catData['id'] as int;
    }

    String parsedCategoriaNombre = json['categoria_nombre'] as String? ??
        (catData is Map ? catData['nombre'] as String? ?? '' : '');

    String parsedCategoriaIcono = json['categoria_icono'] as String? ??
        (catData is Map ? catData['icono'] as String? ?? 'package' : 'package');

    return MaterialModel(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      areaId: parsedAreaId,
      areaNombre: parsedAreaNombre,
      categoriaId: parsedCategoriaId,
      categoriaNombre: parsedCategoriaNombre,
      categoriaIcono: parsedCategoriaIcono,
      stockTotal: stockTotal,
      stockMinimo: stockMinimo,
      diasAlertaCaducidad: json['dias_alerta_caducidad'] as int? ?? 30,
      fechaCaducidadProxima: json['fecha_caducidad_proxima'] as String?,
      unidadMedida: json['unidad_medida'] as String? ?? 'unidades',
      icono: json['icono'] as String?,
    );
  }
}

class LoteModel {
  final int id;
  final int materialId;
  final String? materialNombre;
  final String numeroLote;
  final int cantidad;
  final String? fechaCaducidad;
  final String? fechaAlerta;
  final double? costoUnitario;
  final bool tieneAlerta;

  const LoteModel({
    required this.id,
    required this.materialId,
    this.materialNombre,
    required this.numeroLote,
    required this.cantidad,
    this.fechaCaducidad,
    this.fechaAlerta,
    this.costoUnitario,
    this.tieneAlerta = false,
  });

  bool get estaVencido {
    if (fechaCaducidad == null || fechaCaducidad!.isEmpty) return false;
    try {
      final exp = DateTime.parse(fechaCaducidad!);
      return exp.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  bool get esVencido => estaVencido;

  bool get esLoteGeneral => numeroLote.toLowerCase().contains('general');

  factory LoteModel.fromJson(Map<String, dynamic> json) {
    double? parseCosto(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int parseInt(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    return LoteModel(
      id: parseInt(json['id']),
      materialId: parseInt(json['material'] ?? json['material_id']),
      materialNombre: json['material_nombre'] as String?,
      numeroLote: json['codigo_lote'] as String? ?? json['numero_lote'] as String? ?? json['codigo'] as String? ?? 'LOTE-${json['id']}',
      cantidad: parseInt(json['cantidad_disponible'] ?? json['cantidad_ingresada'] ?? json['cantidad']),
      fechaCaducidad: json['fecha_caducidad'] as String?,
      fechaAlerta: json['fecha_alerta_vencimiento'] as String? ?? json['fecha_alerta'] as String?,
      costoUnitario: parseCosto(json['costo'] ?? json['costo_unitario']),
      tieneAlerta: json['alerta_activa'] as bool? ?? json['tiene_alerta'] as bool? ?? false,
    );
  }
}

class MovimientoHistorialModel {
  final dynamic id;
  final int materialId;
  final String tipo; // 'entrada', 'salida', 'ajuste'
  final int cantidad;
  final int? cantidadAnterior;
  final int? cantidadNueva;
  final String? loteCodigo;
  final String usuarioNombre;
  final String? motivo;
  final String fecha;

  const MovimientoHistorialModel({
    required this.id,
    required this.materialId,
    required this.tipo,
    required this.cantidad,
    this.cantidadAnterior,
    this.cantidadNueva,
    this.loteCodigo,
    required this.usuarioNombre,
    this.motivo,
    required this.fecha,
  });

  factory MovimientoHistorialModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    String tipo = (json['tipo'] as String? ?? '').toLowerCase();
    if (tipo.isEmpty) {
      if (json.containsKey('cantidad_anterior') || json.containsKey('cantidad_nueva')) {
        tipo = 'ajuste';
      } else {
        tipo = 'salida';
      }
    }

    final cant = parseInt(json['cantidad'] ?? json['cantidad_total'] ?? json['cantidad_nueva']);

    return MovimientoHistorialModel(
      id: json['id'] ?? json['movimiento_id'] ?? 0,
      materialId: parseInt(json['material_id'] ?? json['material']),
      tipo: tipo,
      cantidad: cant,
      cantidadAnterior: json['cantidad_anterior'] != null ? parseInt(json['cantidad_anterior']) : null,
      cantidadNueva: json['cantidad_nueva'] != null ? parseInt(json['cantidad_nueva']) : null,
      loteCodigo: json['lote_codigo'] as String?,
      usuarioNombre: json['usuario_nombre'] as String? ??
          json['usuario_username'] as String? ??
          (json['usuario'] is Map ? json['usuario']['username'] : json['usuario']?.toString()) ??
          'Sistema',
      motivo: json['motivo'] as String? ?? json['motivo_destino'] as String?,
      fecha: json['fecha_hora'] as String? ?? json['creado_en'] as String? ?? json['fecha'] as String? ?? '',
    );
  }
}

class SolicitudModel {
  final int id;
  final int materialId;
  final String materialNombre;
  final String? nombreMaterialNuevo;
  final String areaNombre;
  final String unidadMedida;
  final int usuarioId;
  final String usuarioNombre;
  final int cantidad;
  final String motivo;
  final String? comentario;
  final String estado; // 'pendiente', 'aprobada', 'rechazada', 'cancelada'
  final String fecha;
  final String? comentarioResolucion;
  final String? resueltaPorNombre;

  const SolicitudModel({
    required this.id,
    required this.materialId,
    required this.materialNombre,
    this.nombreMaterialNuevo,
    this.areaNombre = '',
    this.unidadMedida = 'unidades',
    required this.usuarioId,
    required this.usuarioNombre,
    required this.cantidad,
    required this.motivo,
    this.comentario,
    required this.estado,
    required this.fecha,
    this.comentarioResolucion,
    this.resueltaPorNombre,
  });

  bool get esPendiente => estado.toLowerCase() == 'pendiente';
  bool get esAprobada => estado.toLowerCase() == 'aprobada';
  bool get esRechazada => estado.toLowerCase() == 'rechazada';
  bool get esCancelada => estado.toLowerCase() == 'cancelada';
  bool get esNuevoMaterial => materialId == 0 || (nombreMaterialNuevo != null && nombreMaterialNuevo!.isNotEmpty);

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    final matId = json['material'] as int? ?? json['material_id'] as int? ?? 0;
    final nombreNuevo = json['nombre_material_nuevo'] as String?;
    final matNombre = json['material_nombre'] as String? ?? (nombreNuevo != null && nombreNuevo.isNotEmpty ? '$nombreNuevo (Nuevo)' : '');

    return SolicitudModel(
      id: json['id'] as int? ?? 0,
      materialId: matId,
      materialNombre: matNombre,
      nombreMaterialNuevo: nombreNuevo,
      areaNombre: json['area_nombre'] as String? ?? '',
      unidadMedida: json['unidad_medida'] as String? ?? 'unidades',
      usuarioId: json['solicitante'] as int? ?? json['usuario'] as int? ?? 0,
      usuarioNombre: json['solicitante_username'] as String? ?? json['usuario_nombre'] as String? ?? '',
      cantidad: json['cantidad_solicitada'] as int? ?? json['cantidad'] as int? ?? 0,
      motivo: json['motivo'] as String? ?? '',
      comentario: json['comentario'] as String?,
      estado: json['estado'] as String? ?? 'pendiente',
      fecha: json['fecha_creacion'] as String? ?? json['creado_en'] as String? ?? '',
      comentarioResolucion: json['comentario_resolucion'] as String?,
      resueltaPorNombre: json['resuelto_por_username'] as String? ?? json['resuelta_por_nombre'] as String?,
    );
  }
}

class AlertaInventarioModel {
  final int id;
  final String tipo; // 'stock_bajo', 'caducidad_proxima'
  final String titulo;
  final String mensaje;
  final String severidad; // 'warning', 'danger'
  final int? materialId;
  final String? materialNombre;

  const AlertaInventarioModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.severidad,
    this.materialId,
    this.materialNombre,
  });

  bool get esCritica => severidad == 'danger' || tipo == 'stock_bajo';

  factory AlertaInventarioModel.fromJson(Map<String, dynamic> json) {
    return AlertaInventarioModel(
      id: json['id'] as int? ?? 0,
      tipo: json['tipo'] as String? ?? 'stock_bajo',
      titulo: json['titulo'] as String? ?? 'Alerta de Inventario',
      mensaje: json['mensaje'] as String? ?? '',
      severidad: json['severidad'] as String? ?? 'warning',
      materialId: json['material_id'] as int? ?? json['material'] as int?,
      materialNombre: json['material_nombre'] as String?,
    );
  }
}
