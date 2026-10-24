import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/icon_catalog.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/permisos_provider.dart';
import '../../providers/storage_provider.dart';

class GestionInventarioScreen extends ConsumerStatefulWidget {
  const GestionInventarioScreen({super.key});

  @override
  ConsumerState<GestionInventarioScreen> createState() => _GestionInventarioScreenState();
}

class _GestionInventarioScreenState extends ConsumerState<GestionInventarioScreen> {
  final TextEditingController _searchMaterialController = TextEditingController();
  String _materialSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchMaterialController.addListener(() {
      setState(() {
        _materialSearchQuery = _searchMaterialController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchMaterialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);
    final puedeAreas = esSuperadmin || (user?.roles.any((r) => r.toLowerCase().contains('admin')) ?? false);

    return DefaultTabController(
      key: ValueKey(puedeAreas),
      length: puedeAreas ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            tooltip: 'Atrás',
            onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
          ),
          title: const Text('Gestión de Inventario'),
          bottom: TabBar(
            indicatorColor: CeosColors.areaOdontologia,
            labelColor: CeosColors.areaOdontologia,
            unselectedLabelColor: CeosColors.lightTextSecondary,
            tabs: [
              const Tab(
                icon: Icon(PhosphorIconsRegular.cube, size: 20),
                text: 'Materiales',
              ),
              const Tab(
                icon: Icon(PhosphorIconsRegular.tag, size: 20),
                text: 'Categorías',
              ),
              if (puedeAreas)
                const Tab(
                  icon: Icon(PhosphorIconsRegular.buildings, size: 20),
                  text: 'Áreas',
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Banner de Entrada de Stock rápido
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CeosColors.areaOdontologia.withValues(alpha: 0.07),
                border: Border(
                  bottom: BorderSide(color: CeosColors.areaOdontologia.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologia.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.arrowSquareIn,
                      color: CeosColors.areaOdontologia,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrada de Nuevo Stock',
                          style: CeosTheme.heading(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Registrar lotes recibidos y existencias',
                          style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/inventario/entrada'),
                    icon: const Icon(PhosphorIconsRegular.plus, size: 14),
                    label: const Text('Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CeosColors.areaOdontologia,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido de Tabs
            Expanded(
              child: TabBarView(
                children: [
                  _buildTabMateriales(),
                  _buildTabCategorias(),
                  if (puedeAreas) _buildTabAreas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: MATERIALES ---
  Widget _buildTabMateriales() {
    final materialesAsync = ref.watch(materialesAdminProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nuevo_material',
        onPressed: () => context.push('/inventario/gestion/material/crear'),
        backgroundColor: CeosColors.areaOdontologia,
        icon: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
        label: const Text(
          'Nuevo Material',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchMaterialController,
              decoration: InputDecoration(
                hintText: 'Filtrar material en catálogo...',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                suffixIcon: _searchMaterialController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(PhosphorIconsRegular.x, size: 16),
                        onPressed: () => _searchMaterialController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(materialesAdminProvider);
              },
              child: materialesAsync.when(
                data: (materiales) {
                  final filtrados = _materialSearchQuery.isEmpty
                      ? materiales
                      : materiales.where((m) {
                          return m.nombre.toLowerCase().contains(_materialSearchQuery) ||
                              m.areaNombre.toLowerCase().contains(_materialSearchQuery) ||
                              m.categoriaNombre.toLowerCase().contains(_materialSearchQuery);
                        }).toList();

                  if (filtrados.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.cube, size: 48, color: CeosColors.lightTextMuted),
                          const SizedBox(height: 12),
                          Text(
                            _materialSearchQuery.isEmpty
                                ? 'No hay materiales en el catálogo'
                                : 'No se encontraron coincidencias',
                            style: CeosTheme.heading(fontSize: 15, color: CeosColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final mat = filtrados[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: CeosColors.areaOdontologia.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              IconCatalog.getIcon(mat.categoriaIcono),
                              color: CeosColors.areaOdontologia,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            mat.nombre,
                            style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      mat.areaNombre.isNotEmpty ? mat.areaNombre : 'Área #${mat.areaId}',
                                      style: CeosTheme.dataMono(fontSize: 10, color: Colors.grey[800]),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      mat.categoriaNombre.isNotEmpty ? mat.categoriaNombre : 'Cat #${mat.categoriaId}',
                                      style: CeosTheme.dataMono(fontSize: 10, color: CeosColors.areaOdontologia),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stock: ${mat.stockTotal} ${mat.unidadMedida} (Mín: ${mat.stockMinimo})',
                                style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextSecondary),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: CeosColors.areaOdontologia),
                            tooltip: 'Editar material',
                            onPressed: () {
                              context.push(
                                '/inventario/gestion/material/${mat.id}/editar',
                                extra: mat,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error al cargar materiales: $err'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: CATEGORÍAS ---
  Widget _buildTabCategorias() {
    final categoriasAsync = ref.watch(categoriasAdminProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nueva_categoria',
        onPressed: () => context.push('/inventario/gestion/categoria/crear'),
        backgroundColor: CeosColors.areaOdontologia,
        icon: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
        label: const Text(
          'Nueva Categoría',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriasAdminProvider);
        },
        child: categoriasAsync.when(
          data: (categorias) {
            if (categorias.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.tag, size: 48, color: CeosColors.lightTextMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No hay categorías registradas',
                      style: CeosTheme.heading(fontSize: 15, color: CeosColors.lightTextSecondary),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: categorias.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cat = categorias[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        IconCatalog.getIcon(cat.icono),
                        color: CeosColors.areaOdontologia,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      cat.nombre,
                      style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: cat.descripcion.isNotEmpty
                        ? Text(
                            cat.descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                          )
                        : Text(
                            'Ícono: ${cat.icono}',
                            style: CeosTheme.dataMono(fontSize: 11, color: Colors.grey[600]),
                          ),
                    trailing: IconButton(
                      icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: CeosColors.areaOdontologia),
                      tooltip: 'Editar categoría',
                      onPressed: () {
                        context.push(
                          '/inventario/gestion/categoria/${cat.id}/editar',
                          extra: cat,
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Error al cargar categorías: $err'),
          ),
        ),
      ),
    );
  }

  // --- TAB 3: ÁREAS (Admin only) ---
  Widget _buildTabAreas() {
    final areasAsync = ref.watch(areasProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nueva_area',
        onPressed: () => context.push('/inventario/gestion/area/crear'),
        backgroundColor: CeosColors.areaOdontologia,
        icon: const Icon(PhosphorIconsRegular.plus, color: Colors.white),
        label: const Text(
          'Nueva Área',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(areasProvider);
        },
        child: areasAsync.when(
          data: (areas) {
            if (areas.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.buildings, size: 48, color: CeosColors.lightTextMuted),
                    const SizedBox(height: 12),
                    Text(
                      'No hay áreas registradas',
                      style: CeosTheme.heading(fontSize: 15, color: CeosColors.lightTextSecondary),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: areas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final area = areas[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        IconCatalog.getIcon(area.icono),
                        color: CeosColors.areaOdontologia,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      area.nombre,
                      style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: area.descripcion.isNotEmpty
                        ? Text(
                            area.descripcion,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                          )
                        : Text(
                            'Ícono: ${area.icono}',
                            style: CeosTheme.dataMono(fontSize: 11, color: Colors.grey[600]),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: CeosColors.areaOdontologia),
                          tooltip: 'Editar área',
                          onPressed: () {
                            context.push(
                              '/inventario/gestion/area/${area.id}/editar',
                              extra: area,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.trash, size: 20, color: CeosColors.statusDanger),
                          tooltip: 'Eliminar área',
                          onPressed: () => _confirmarEliminarArea(area),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Text('Error al cargar áreas: $err'),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarArea(AreaModel area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Área?'),
        content: Text(
          'El área "${area.nombre}" será eliminada permanentemente. '
          'Si tiene materiales asociados, el servidor rechazará la operación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      await repo.eliminarArea(area.id);
      ref.invalidate(areasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Área "${area.nombre}" eliminada exitosamente.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar área: $e'),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    }
  }
}
