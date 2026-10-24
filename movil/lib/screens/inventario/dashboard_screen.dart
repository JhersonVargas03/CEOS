import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/storage_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _diasRango = 30;
  List<Map<String, dynamic>> _masUsados = [];
  List<Map<String, dynamic>> _reposicion = [];
  Map<String, dynamic>? _gastos;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final masUsados = await repo.obtenerDashboardMasUsados(dias: _diasRango);
      final reposicion = await repo.obtenerReposicionPreventiva();
      final gastos = await repo.obtenerReporteGastos();

      setState(() {
        _masUsados = masUsados;
        _reposicion = reposicion;
        _gastos = gastos;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Dashboard y Estadísticas'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: CeosColors.areaOdontologia,
          indicatorColor: CeosColors.areaOdontologia,
          tabs: const [
            Tab(text: 'Más Usados'),
            Tab(text: 'Reposición'),
            Tab(text: 'Gastos'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: CeosColors.statusDanger),
                          const SizedBox(height: 12),
                          Text('Error: $_errorMessage', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _cargarDashboard,
                            icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabMasUsados(),
                      _buildTabReposicion(),
                      _buildTabGastos(),
                    ],
                  ),
      ),
    );
  }

  // --- Tab 1: Materiales Más Usados (Ranking con barras proporcionales) ---
  Widget _buildTabMasUsados() {
    final maxCantidad = _masUsados.fold<int>(
      1,
      (max, item) {
        final cant = (item['total_salidas'] as int?) ?? (item['cantidad'] as int?) ?? 1;
        return cant > max ? cant : max;
      },
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ranking de Uso',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: _diasRango,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('Últimos 7 días')),
                  DropdownMenuItem(value: 30, child: Text('Últimos 30 días')),
                  DropdownMenuItem(value: 90, child: Text('Últimos 90 días')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _diasRango = val);
                    _cargarDashboard();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_masUsados.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No hay datos de consumo en este período.',
                  style: CeosTheme.body(color: CeosColors.lightTextMuted),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _masUsados.length,
              itemBuilder: (context, index) {
                final item = _masUsados[index];
                final nombre = item['material_nombre'] as String? ?? item['nombre'] as String? ?? 'Material';
                final total = (item['total_salidas'] as int?) ?? (item['cantidad'] as int?) ?? 0;
                final fraccion = (total / maxCantidad).clamp(0.05, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                                      : index == 1
                                          ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                                          : CeosColors.areaOdontologia.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: CeosTheme.dataMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: CeosColors.areaOdontologia,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                nombre,
                                style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Text(
                            '$total un.',
                            style: CeosTheme.dataMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: CeosColors.areaOdontologia,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraccion,
                          minHeight: 6,
                          backgroundColor: Colors.grey.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(CeosColors.areaOdontologia),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Tab 2: Reposición Preventiva ---
  Widget _buildTabReposicion() {
    if (_reposicion.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsFill.checkCircle, size: 44, color: CeosColors.statusSuccess),
              const SizedBox(height: 12),
              Text(
                'No hay materiales con alerta de reposición preventiva.',
                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reposicion.length,
      itemBuilder: (context, index) {
        final item = _reposicion[index];
        final nombre = item['material_nombre'] as String? ?? 'Material';
        final motivo = item['motivo'] as String? ?? 'Rotación baja / Próximo a agotarse';
        final stock = item['stock_actual'] ?? item['stock'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CeosColors.statusWarningLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.bellRinging, color: CeosColors.statusWarning, size: 20),
            ),
            title: Text(nombre, style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(motivo, style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary)),
            trailing: Text(
              'Stock: $stock',
              style: CeosTheme.dataMono(fontSize: 12, fontWeight: FontWeight.bold, color: CeosColors.statusWarning),
            ),
          ),
        );
      },
    );
  }

  // --- Tab 3: Reporte de Gastos (HU-422) ---
  Widget _buildTabGastos() {
    if (_gastos == null) {
      return const Center(child: Text('No hay datos de gastos disponibles.'));
    }

    final porCategoria = _gastos!['por_categoria'] as List<dynamic>? ?? [];
    final porMaterial = _gastos!['por_material'] as List<dynamic>? ?? [];
    final costoIncompleto = _gastos!['costo_incompleto'] as bool? ?? false;
    final totalGasto = _gastos!['total_gastado'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Advertencia si aplica costo incompleto (HU-422)
          if (costoIncompleto) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CeosColors.statusWarningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CeosColors.statusWarning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.warning, color: CeosColors.statusWarning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠ Costo incompleto: existen lotes registrados sin costo unitario digitado.',
                      style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Total Acumulado Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CeosColors.areaOdontologiaLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gasto Total Registrado',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '\$$totalGasto',
                  style: CeosTheme.dataMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CeosColors.areaOdontologia,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Desglose por Categoría',
            style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...porCategoria.map((c) {
            final catMap = c as Map<String, dynamic>;
            final catNombre = catMap['categoria'] as String? ?? catMap['nombre'] as String? ?? 'Categoría';
            final total = catMap['total'] ?? catMap['gasto'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(catNombre, style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: Text(
                  '\$$total',
                  style: CeosTheme.dataMono(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),

          if (porMaterial.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Desglose por Material',
              style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...porMaterial.map((m) {
              final matMap = m as Map<String, dynamic>;
              final matNombre = matMap['material'] as String? ?? matMap['nombre'] as String? ?? 'Material';
              final total = matMap['total'] ?? matMap['gasto'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(matNombre, style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: Text(
                    '\$$total',
                    style: CeosTheme.dataMono(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
