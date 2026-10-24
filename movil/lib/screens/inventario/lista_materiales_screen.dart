import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/permisos_provider.dart';
import '../../widgets/card_material.dart';
import '../../widgets/ceos_shimmer.dart';
import '../../widgets/chips_categoria.dart';
import '../../widgets/selector_area.dart';

class ListaMaterialesScreen extends ConsumerStatefulWidget {
  const ListaMaterialesScreen({super.key});

  @override
  ConsumerState<ListaMaterialesScreen> createState() => _ListaMaterialesScreenState();
}

class _ListaMaterialesScreenState extends ConsumerState<ListaMaterialesScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int? _categoriaSeleccionadaId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Debounce de ~400ms para búsqueda (HU-412)
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      final area = ref.read(areaSeleccionadaProvider);
      ref.read(filtroMaterialesProvider.notifier).state = FiltroMateriales(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        areaId: area?.id,
        categoriaId: _categoriaSeleccionadaId,
      );
    });
  }

  void _onCategoriaSelected(int? catId) {
    setState(() => _categoriaSeleccionadaId = catId);
    final area = ref.read(areaSeleccionadaProvider);
    ref.read(filtroMaterialesProvider.notifier).state = FiltroMateriales(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      areaId: area?.id,
      categoriaId: catId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaSeleccionada = ref.watch(areaSeleccionadaProvider);
    final categoriasAsync = ref.watch(categoriasProvider(areaSeleccionada?.id));
    final materialesAsync = ref.watch(materialesFiltradosProvider);
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);

    final puedeRegistrarEntrada = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('registrar_entrada') || p.contains('gestionar_inventario'),
          orElse: () => false,
        );

    final puedeGestionarCatalogo = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('gestionar_catalogo_inventario'),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Inicio',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Inventario de Materiales'),
        actions: [
          if (puedeGestionarCatalogo)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.slidersHorizontal, size: 22),
              tooltip: 'Gestión de Catálogo',
              onPressed: () => context.push('/inventario/gestion'),
            ),
          if (puedeRegistrarEntrada)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.plusCircle, size: 24),
              tooltip: 'Registrar Entrada',
              onPressed: () => context.push('/inventario/entrada'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selector de Área
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SelectorArea(
                showHeader: false,
                onAreaSelected: (area) {
                  setState(() => _categoriaSeleccionadaId = null);
                },
              ),
            ),

            // Search Bar con Debounce (HU-412)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar material por nombre o código...',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged();
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Chips de Categorías (HU-412 / T-AJUSTE-MV.45)
            // Solo se muestran las categorías cuando hay un área seleccionada
            if (areaSeleccionada != null)
              categoriasAsync.maybeWhen(
                data: (categorias) => categorias.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ChipsCategoria(
                          categorias: categorias,
                          categoriaSeleccionadaId: _categoriaSeleccionadaId,
                          onCategoriaSelected: _onCategoriaSelected,
                        ),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),

            const SizedBox(height: 6),

            // Lista de Materiales con pull-to-refresh
            Expanded(
              child: materialesAsync.when(
                data: (materiales) {
                  if (materiales.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              PhosphorIconsRegular.package,
                              size: 48,
                              color: CeosColors.lightTextMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No se encontraron materiales.',
                              style: CeosTheme.heading(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prueba ajustando los filtros o agregando nuevos lotes.',
                              style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(materialesFiltradosProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: materiales.length,
                      itemBuilder: (context, index) {
                        final mat = materiales[index];
                        return CardMaterial(
                          material: mat,
                          onTap: () {
                            context.push('/inventario/material/${mat.id}');
                          },
                        );
                      },
                    ),
                  );
                },
                loading: () => const SkeletonListaMateriales(),
                error: (e, _) => Center(
                  child: Text(
                    'Error al cargar materiales: $e',
                    style: CeosTheme.body(color: CeosColors.statusDanger),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (puedeRegistrarEntrada || puedeGestionarCatalogo)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (puedeGestionarCatalogo)
                  FloatingActionButton.extended(
                    heroTag: 'fab_nuevo_material',
                    backgroundColor: CeosColors.lightSurface,
                    foregroundColor: CeosColors.areaOdontologia,
                    icon: const Icon(PhosphorIconsRegular.cube, size: 20),
                    label: const Text('Nuevo Material', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final area = ref.read(areaSeleccionadaProvider);
                      final nuevo = await context.push<MaterialModel>('/inventario/materiales/crear?areaId=${area?.id ?? ''}');
                      if (nuevo != null && context.mounted) {
                        ref.invalidate(materialesFiltradosProvider);
                      }
                    },
                  ),
                if (puedeGestionarCatalogo && puedeRegistrarEntrada) const SizedBox(height: 10),
                if (puedeRegistrarEntrada)
                  FloatingActionButton.extended(
                    heroTag: 'fab_registrar_entrada',
                    backgroundColor: CeosColors.areaOdontologia,
                    foregroundColor: Colors.white,
                    icon: const Icon(PhosphorIconsRegular.plus, size: 20),
                    label: const Text('Registrar Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      context.push('/inventario/entrada');
                    },
                  ),
              ],
            )
          : null,
    );
  }
}
