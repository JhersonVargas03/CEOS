import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventario_models.dart';
import '../repositories/inventario_repository.dart';
import 'storage_provider.dart';

final areasProvider = FutureProvider<List<AreaModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerAreas();
});

// Area seleccionada persistida en el flujo activo (T-411.2)
final areaSeleccionadaProvider = StateProvider<AreaModel?>((ref) => null);

final categoriasProvider = FutureProvider.family<List<CategoriaModel>, int?>((ref, areaId) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerCategorias(areaId: areaId);
});

class FiltroMateriales {
  final String? query;
  final int? areaId;
  final int? categoriaId;

  const FiltroMateriales({
    this.query,
    this.areaId,
    this.categoriaId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FiltroMateriales &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          areaId == other.areaId &&
          categoriaId == other.categoriaId;

  @override
  int get hashCode => Object.hash(query, areaId, categoriaId);
}

final filtroMaterialesProvider = StateProvider<FiltroMateriales>((ref) {
  final area = ref.watch(areaSeleccionadaProvider);
  return FiltroMateriales(areaId: area?.id);
});

final materialesFiltradosProvider = FutureProvider<List<MaterialModel>>((ref) async {
  final filtro = ref.watch(filtroMaterialesProvider);
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.buscarMateriales(
    query: filtro.query,
    areaId: filtro.areaId,
    categoriaId: filtro.categoriaId,
  );
});

final alertasActivasProvider = FutureProvider<List<AlertaInventarioModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerAlertasActivas();
});

final misSolicitudesProvider = FutureProvider<List<SolicitudModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerMisSolicitudes();
});

final solicitudesPendientesProvider = FutureProvider<List<SolicitudModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerSolicitudesPendientes();
});

// Providers para gestión y administración del catálogo
final materialesAdminProvider = FutureProvider<List<MaterialModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.buscarMateriales();
});

final categoriasAdminProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerCategorias();
});

final iconosDisponiblesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(inventarioRepositoryProvider);
  return await repo.obtenerIconosDisponibles();
});
