import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/icon_catalog.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/permisos_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/item_actividad_reciente.dart';

class DetalleMaterialScreen extends ConsumerStatefulWidget {
  final int materialId;

  const DetalleMaterialScreen({
    super.key,
    required this.materialId,
  });

  @override
  ConsumerState<DetalleMaterialScreen> createState() => _DetalleMaterialScreenState();
}

class _DetalleMaterialScreenState extends ConsumerState<DetalleMaterialScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  MaterialModel? _material;
  List<LoteModel> _lotes = [];
  List<MovimientoHistorialModel> _historial = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with a safe default length; will be updated after async data loads
    _tabController = TabController(length: 2, vsync: this);
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final mat = await repo.obtenerDetalleMaterial(widget.materialId);
      final lotes = await repo.obtenerLotesMaterial(widget.materialId);
      final hist = await repo.obtenerHistorialMaterial(widget.materialId);

      final tienePermisoAjuste = ref.read(esSuperadminProvider) ||
          ref.read(permisosEfectivosProvider).maybeWhen(
                data: (p) => p.contains('ajustar_inventario'),
                orElse: () => false,
              );

      final newLength = tienePermisoAjuste ? 3 : 2;
      // Dispose previous controller before replacing it
      _tabController.dispose();
      _tabController = TabController(
        length: newLength,
        vsync: this,
      );

      setState(() {
        _material = mat;
        _lotes = lotes;
        _historial = hist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);

    final puedeEntrada = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('registrar_entrada'),
          orElse: () => false,
        );

    final puedeSalida = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('registrar_salida'),
          orElse: () => false,
        );

    final puedeSolicitar = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('solicitar_material'),
          orElse: () => false,
        );

    final tienePermisoAjuste = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('ajustar_inventario'),
          orElse: () => false,
        );

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Material')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _material == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Material')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_errorMessage'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _cargarDetalle,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final mat = _material!;
    final ribbonColor = mat.estadoRibbon == EstadoRibbon.critico
        ? CeosColors.statusDanger
        : mat.estadoRibbon == EstadoRibbon.advertencia
            ? CeosColors.statusWarning
            : CeosColors.statusSuccess;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: Text(mat.nombre),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Resumen Superior del Material
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologiaLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      IconCatalog.getIcon(mat.categoriaIcono),
                      size: 28,
                      color: CeosColors.areaOdontologia,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mat.nombre,
                          style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mat.areaNombre} • ${mat.categoriaNombre}',
                          style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${mat.stockTotal}',
                        style: CeosTheme.dataMono(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ribbonColor,
                        ),
                      ),
                      Text(
                        '${mat.unidadMedida} (mín. ${mat.stockMinimo})',
                        style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // TabBar (Lotes / Historial / Ajustes condicional) (HU-413)
            TabBar(
              controller: _tabController,
              labelColor: CeosColors.areaOdontologia,
              unselectedLabelColor: CeosColors.lightTextSecondary,
              indicatorColor: CeosColors.areaOdontologia,
              tabs: [
                const Tab(text: 'Lotes Activos'),
                const Tab(text: 'Historial'),
                if (tienePermisoAjuste) const Tab(text: 'Ajustes'),
              ],
            ),

            // Contenido de Tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Lotes
                  _buildTabLotes(),
                  // Tab 2: Historial
                  _buildTabHistorial(),
                  // Tab 3: Ajustes condicional
                  if (tienePermisoAjuste) _buildTabAjustes(),
                ],
              ),
            ),

            // Barra Inferior de Acciones Rápidas (Entrada, Salida, Solicitar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  if (puedeEntrada)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CeosColors.statusSuccess,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(PhosphorIconsRegular.arrowSquareIn, size: 18),
                          label: const Text('Entrada'),
                          onPressed: () async {
                            await context.push('/inventario/entrada?materialId=${mat.id}');
                            _cargarDetalle();
                          },
                        ),
                      ),
                    ),
                  if (puedeSalida)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CeosColors.areaOdontologia,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 18),
                          label: const Text('Salida'),
                          onPressed: mat.stockTotal > 0
                              ? () async {
                                  await context.push('/inventario/salida?materialId=${mat.id}');
                                  _cargarDetalle();
                                }
                              : null,
                        ),
                      ),
                    ),
                  if (puedeSolicitar)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
                          label: const Text('Pedir'),
                          onPressed: () async {
                            await context.push('/inventario/solicitar?materialId=${mat.id}');
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabLotes() {
    if (_lotes.isEmpty) {
      return Center(
        child: Text(
          'No hay lotes registrados para este material.',
          style: CeosTheme.body(color: CeosColors.lightTextMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lotes.length,
      itemBuilder: (context, index) {
        final lote = _lotes[index];
        final alertColor = lote.estaVencido
            ? CeosColors.statusDanger
            : lote.tieneAlerta
                ? CeosColors.statusWarning
                : CeosColors.statusSuccess;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  color: alertColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lote.numeroLote,
                        style: CeosTheme.dataMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (lote.fechaCaducidad != null && lote.fechaCaducidad!.isNotEmpty)
                            ? 'Caduca: ${lote.fechaCaducidad}'
                            : 'Sin caducidad',
                        style: CeosTheme.body(
                          fontSize: 12,
                          color: lote.estaVencido ? CeosColors.statusDanger : CeosColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${lote.cantidad} un.',
                  style: CeosTheme.dataMono(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: alertColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabHistorial() {
    if (_historial.isEmpty) {
      return Center(
        child: Text(
          'No hay movimientos registrados.',
          style: CeosTheme.body(color: CeosColors.lightTextMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _historial.length,
      itemBuilder: (context, index) {
        final mov = _historial[index];
        return ItemActividadReciente(movimiento: mov);
      },
    );
  }

  Widget _buildTabAjustes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CeosColors.statusWarningLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CeosColors.statusWarning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.warning, color: CeosColors.statusWarning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Los ajustes manuales son auditados con motivo obligatorio.',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusWarning),
            icon: const Icon(PhosphorIconsRegular.slidersHorizontal),
            label: const Text('Realizar Ajuste de Lote'),
            onPressed: () async {
              await context.push('/inventario/ajuste?materialId=${widget.materialId}');
              _cargarDetalle();
            },
          ),
        ],
      ),
    );
  }
}
