import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/inventario_models.dart';

class InventarioRepository {
  final ApiClient _apiClient;

  InventarioRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  // --- Áreas y Categorías ---
  Future<List<AreaModel>> obtenerAreas() async {
    final response = await _apiClient.get(AppConstants.endpointAreas);
    final list = response.data as List<dynamic>;
    return list.map((e) => AreaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AreaModel> crearArea({
    required String nombre,
    String descripcion = '',
    String icono = 'package',
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointAreas,
      data: {
        'nombre': nombre,
        'descripcion': descripcion,
        'icono': icono,
      },
    );
    return AreaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<CategoriaModel>> obtenerCategorias({int? areaId}) async {
    final query = areaId != null ? {'area_id': areaId} : null;
    final response = await _apiClient.get(
      AppConstants.endpointCategorias,
      queryParameters: query,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => CategoriaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CategoriaModel> crearCategoria({
    required String nombre,
    String descripcion = '',
    String icono = 'package',
    int? areaId,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointCategorias,
      data: {
        'nombre': nombre,
        'descripcion': descripcion,
        'icono': icono,
        if (areaId != null) 'area_id': areaId,
      },
    );
    return CategoriaModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Materiales ---
  Future<List<MaterialModel>> buscarMateriales({
    String? query,
    int? areaId,
    int? categoriaId,
  }) async {
    final params = <String, dynamic>{};
    if (query != null && query.trim().isNotEmpty) {
      params['search'] = query.trim();
    }
    if (areaId != null) {
      params['area_id'] = areaId;
    }
    if (categoriaId != null) {
      params['categoria_id'] = categoriaId;
    }

    final response = await _apiClient.get(
      AppConstants.endpointMateriales,
      queryParameters: params.isNotEmpty ? params : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => MaterialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MaterialModel> obtenerDetalleMaterial(int materialId) async {
    final response = await _apiClient.get('${AppConstants.endpointMateriales}/$materialId');
    return MaterialModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MaterialModel> crearMaterial({
    required String nombre,
    required int areaId,
    required int categoriaId,
    int stockMinimo = 5,
    int diasAlertaCaducidad = 30,
    String unidadMedida = 'unidades',
    int? stockInicial,
    String? codigoLote,
    String? fechaCaducidad,
    double? costoUnitario,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointMateriales,
      data: {
        'nombre': nombre,
        'area_id': areaId,
        'categoria_id': categoriaId,
        'stock_minimo': stockMinimo,
        'unidad_medida': unidadMedida,
        if (stockInicial != null && stockInicial > 0) 'stock_inicial': stockInicial,
        if (codigoLote != null && codigoLote.isNotEmpty) 'codigo_lote': codigoLote,
        if (fechaCaducidad != null && fechaCaducidad.isNotEmpty) 'fecha_caducidad': fechaCaducidad,
        if (costoUnitario != null) 'costo_unitario': costoUnitario,
      },
    );
    return MaterialModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Lotes ---
  Future<List<LoteModel>> obtenerLotesMaterial(int materialId) async {
    final response = await _apiClient.get(
      '${AppConstants.endpointMateriales}/$materialId/lotes',
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => LoteModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoteModel> registrarEntrada({
    required int materialId,
    required int cantidad,
    String? fechaCaducidad,
    String? fechaAlerta,
    double? costoUnitario,
    String? numeroLote,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointLotes,
      data: {
        'material_id': materialId,
        'material': materialId,
        'cantidad_ingresada': cantidad,
        'cantidad': cantidad,
        if (fechaCaducidad != null && fechaCaducidad.isNotEmpty) 'fecha_caducidad': fechaCaducidad,
        if (fechaAlerta != null && fechaAlerta.isNotEmpty) ...{
          'fecha_alerta_vencimiento': fechaAlerta,
          'fecha_alerta': fechaAlerta,
        },
        if (costoUnitario != null) ...{
          'costo': costoUnitario,
          'costo_unitario': costoUnitario,
        },
        if (numeroLote != null && numeroLote.isNotEmpty) ...{
          'codigo_lote': numeroLote,
          'numero_lote': numeroLote,
        },
      },
    );
    return LoteModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Salidas FEFO ---
  Future<Map<String, dynamic>> registrarSalida({
    required int materialId,
    required int cantidad,
    String? motivo,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointSalidas,
      data: {
        'material_id': materialId,
        'material': materialId,
        'cantidad': cantidad,
        'motivo_destino': (motivo != null && motivo.isNotEmpty) ? motivo : 'Uso en atención clínica',
        'motivo': (motivo != null && motivo.isNotEmpty) ? motivo : 'Uso en atención clínica',
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // --- Ajustes de Inventario ---
  Future<Map<String, dynamic>> registrarAjuste({
    int? loteId,
    int? materialId,
    required int cantidadNueva,
    required String motivo,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointAjustes,
      data: {
        if (loteId != null) 'lote_id': loteId,
        if (loteId != null) 'lote': loteId,
        if (materialId != null) 'material_id': materialId,
        if (materialId != null) 'material': materialId,
        'cantidad_nueva': cantidadNueva,
        'motivo': motivo,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<MovimientoHistorialModel>> obtenerHistorialMaterial(int materialId) async {
    try {
      final response = await _apiClient.get('${AppConstants.endpointMateriales}/$materialId/movimientos');
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MovimientoHistorialModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      final response = await _apiClient.get(
        AppConstants.endpointAjustes,
        queryParameters: {'material_id': materialId},
      );
      if (response.data is List) {
        return (response.data as List)
            .map((e) => MovimientoHistorialModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  // --- Solicitudes de Material ---
  Future<SolicitudModel> crearSolicitud({
    int? materialId,
    String? nombreMaterialNuevo,
    int? areaId,
    String? unidadMedida,
    required int cantidad,
    required String motivo,
    String? comentario,
  }) async {
    final payload = <String, dynamic>{
      if (materialId != null && materialId > 0) 'material_id': materialId,
      if (nombreMaterialNuevo != null && nombreMaterialNuevo.trim().isNotEmpty)
        'nombre_material_nuevo': nombreMaterialNuevo.trim(),
      if (areaId != null) 'area_id': areaId,
      if (unidadMedida != null && unidadMedida.trim().isNotEmpty)
        'unidad_medida': unidadMedida.trim(),
      'cantidad_solicitada': cantidad,
      'motivo': motivo,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
    };

    final response = await _apiClient.post(
      AppConstants.endpointSolicitudes,
      data: payload,
    );
    return SolicitudModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SolicitudModel>> obtenerMisSolicitudes() async {
    final response = await _apiClient.get(
      AppConstants.endpointSolicitudes,
      queryParameters: {'mis_solicitudes': true},
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => SolicitudModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SolicitudModel>> obtenerSolicitudesPendientes() async {
    final response = await _apiClient.get(
      AppConstants.endpointSolicitudes,
      queryParameters: {'estado': 'pendiente'},
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => SolicitudModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SolicitudModel>> obtenerTodasSolicitudes({
    String? estado,
    int? usuarioId,
    int? materialId,
  }) async {
    final params = <String, dynamic>{};
    if (estado != null && estado.isNotEmpty) params['estado'] = estado;
    if (usuarioId != null) params['usuario'] = usuarioId;
    if (materialId != null) params['material'] = materialId;

    final response = await _apiClient.get(
      AppConstants.endpointSolicitudes,
      queryParameters: params.isNotEmpty ? params : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => SolicitudModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SolicitudModel> editarSolicitud({
    required int solicitudId,
    required int cantidad,
    required String motivo,
    String? comentario,
  }) async {
    final response = await _apiClient.patch(
      '${AppConstants.endpointSolicitudes}/$solicitudId',
      data: {
        'cantidad': cantidad,
        'motivo': motivo,
        if (comentario != null) 'comentario': comentario,
      },
    );
    return SolicitudModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> cancelarSolicitud(int solicitudId) async {
    await _apiClient.post(
      '${AppConstants.endpointSolicitudes}/$solicitudId/cancelar',
    );
  }

  Future<void> resolverSolicitud({
    required int solicitudId,
    required String accion, // 'aprobar' o 'rechazar'
    String? comentarioResolucion,
  }) async {
    await _apiClient.post(
      '${AppConstants.endpointSolicitudes}/$solicitudId/resolver',
      data: {
        'accion': accion,
        // Enviamos ambos campos para máxima compatibilidad con el serializer del backend
        if (comentarioResolucion != null && comentarioResolucion.isNotEmpty) ...{
          'comentario_resolucion': comentarioResolucion,
          'comentario': comentarioResolucion,
        },
      },
    );
  }

  // --- Eliminar Área (solo admin/superadmin) ---
  Future<void> eliminarArea(int areaId) async {
    await _apiClient.delete('${AppConstants.endpointAreas}/$areaId');
  }

  // --- Alertas ---
  Future<List<AlertaInventarioModel>> obtenerAlertasActivas() async {
    try {
      final materiales = await buscarMateriales();
      final alertas = <AlertaInventarioModel>[];

      for (final m in materiales) {
        if (m.estadoRibbon == EstadoRibbon.critico) {
          alertas.add(
            AlertaInventarioModel(
              id: m.id,
              tipo: 'stock_bajo',
              titulo: 'Stock Crítico: ${m.nombre}',
              mensaje: 'Quedan ${m.stockTotal} ${m.unidadMedida} (mínimo: ${m.stockMinimo})',
              severidad: 'danger',
              materialId: m.id,
              materialNombre: m.nombre,
            ),
          );
        } else if (m.estadoRibbon == EstadoRibbon.advertencia) {
          alertas.add(
            AlertaInventarioModel(
              id: m.id,
              tipo: 'caducidad_proxima',
              titulo: 'Próximo a Vencer: ${m.nombre}',
              mensaje: 'Lote vence el ${m.fechaCaducidadProxima ?? "pronto"}',
              severidad: 'warning',
              materialId: m.id,
              materialNombre: m.nombre,
            ),
          );
        }
      }
      return alertas;
    } catch (_) {
      return [];
    }
  }

  // --- Reportes PDF y Dashboard ---
  Future<Map<String, dynamic>> generarReportePDF({
    String? fechaInicio,
    String? fechaFin,
    int? usuarioId,
  }) async {
    final response = await _apiClient.post(
      AppConstants.endpointReportesPdf,
      queryParameters: {'formato': 'json'},
      data: {
        'formato': 'json',
        if (fechaInicio != null) 'fecha_inicio': fechaInicio,
        if (fechaFin != null) 'fecha_fin': fechaFin,
        if (usuarioId != null) 'usuario_id': usuarioId,
      },
    );
    if (response.data is Map) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{
      'mensaje': 'Reporte PDF generado exitosamente.',
      'raw': response.data.toString(),
    };
  }

  Future<void> enviarReporteMensajeria({
    int? reporteId,
    String? fechaInicio,
    String? fechaFin,
    int? usuarioId,
  }) async {
    await _apiClient.post(
      AppConstants.endpointReportesEnviarMensajeria,
      data: {
        if (reporteId != null) 'reporte_id': reporteId,
        if (fechaInicio != null) 'fecha_inicio': fechaInicio,
        if (fechaFin != null) 'fecha_fin': fechaFin,
        if (usuarioId != null) 'usuario_id': usuarioId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialReportes() async {
    final response = await _apiClient.get(AppConstants.endpointReportesHistorial);
    if (response.data is Map && response.data['reportes'] is List) {
      return List<Map<String, dynamic>>.from(response.data['reportes'] as List);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> obtenerDashboardMasUsados({
    int dias = 30,
    int? areaId,
    int? categoriaId,
  }) async {
    final params = <String, dynamic>{'dias': dias};
    if (areaId != null) params['area_id'] = areaId;
    if (categoriaId != null) params['categoria_id'] = categoriaId;

    final response = await _apiClient.get(
      AppConstants.endpointDashboardMasUsados,
      queryParameters: params,
    );
    // El endpoint puede devolver una lista directa o un mapa con la lista anidada
    final data = response.data;
    List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      rawList = (data['materiales_mas_usados'] as List<dynamic>?) ??
          (data['results'] as List<dynamic>?) ??
          [];
    } else {
      rawList = [];
    }
    return rawList.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> obtenerReposicionPreventiva() async {
    final response = await _apiClient.get(AppConstants.endpointDashboardReposicion);
    final data = response.data;
    List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map) {
      rawList = (data['solicitudes_preventivas'] as List<dynamic>?) ??
          (data['materiales'] as List<dynamic>?) ??
          (data['results'] as List<dynamic>?) ??
          [];
    } else {
      rawList = [];
    }
    return rawList.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> obtenerReporteGastos({
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final params = <String, dynamic>{};
    if (fechaInicio != null) params['fecha_inicio'] = fechaInicio;
    if (fechaFin != null) params['fecha_fin'] = fechaFin;

    final response = await _apiClient.get(
      AppConstants.endpointReporteGastos,
      queryParameters: params.isNotEmpty ? params : null,
    );
    return response.data as Map<String, dynamic>;
  }
  // --- Actualizar Material (admin/gestor) ---
  Future<MaterialModel> actualizarMaterial(
    int materialId, {
    String? nombre,
    String? descripcion,
    String? unidadMedida,
    int? stockMinimo,
    bool? activo,
  }) async {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (descripcion != null) data['descripcion'] = descripcion;
    if (unidadMedida != null) data['unidad_medida'] = unidadMedida;
    if (stockMinimo != null) data['stock_minimo'] = stockMinimo;
    if (activo != null) data['activo'] = activo;

    final response = await _apiClient.patch(
      '${AppConstants.endpointMateriales}/$materialId',
      data: data,
    );
    return MaterialModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Actualizar Categoría (admin/gestor) ---
  Future<CategoriaModel> actualizarCategoria(
    int categoriaId, {
    String? nombre,
    String? descripcion,
    String? icono,
  }) async {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (descripcion != null) data['descripcion'] = descripcion;
    if (icono != null) data['icono'] = icono;

    final response = await _apiClient.patch(
      '${AppConstants.endpointCategorias}/$categoriaId',
      data: data,
    );
    return CategoriaModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Actualizar Área (solo admin) ---
  Future<AreaModel> actualizarArea(
    int areaId, {
    String? nombre,
    String? descripcion,
    String? icono,
  }) async {
    final data = <String, dynamic>{};
    if (nombre != null) data['nombre'] = nombre;
    if (descripcion != null) data['descripcion'] = descripcion;
    if (icono != null) data['icono'] = icono;

    final response = await _apiClient.patch(
      '${AppConstants.endpointAreas}/$areaId',
      data: data,
    );
    return AreaModel.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Íconos disponibles ---
  Future<List<String>> obtenerIconosDisponibles() async {
    try {
      final response = await _apiClient.get(AppConstants.endpointIconos);
      final list = response.data as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      // Fallback estático si el endpoint falla
      return [
        'package', 'tooth', 'sparkle', 'heartbeat', 'syringe',
        'firstAid', 'pill', 'bandaids', 'stethoscope', 'virus',
        'thermometer', 'warehouse', 'scissors', 'mask',
      ];
    }
  }
}
