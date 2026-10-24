import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/badge_estado.dart';

class TodasSolicitudesScreen extends ConsumerStatefulWidget {
  const TodasSolicitudesScreen({super.key});

  @override
  ConsumerState<TodasSolicitudesScreen> createState() => _TodasSolicitudesScreenState();
}

class _TodasSolicitudesScreenState extends ConsumerState<TodasSolicitudesScreen> {
  List<SolicitudModel> _solicitudes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _filtroEstado;

  final List<String> _estados = ['todas', 'pendiente', 'aprobada', 'rechazada', 'cancelada'];

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final list = await repo.obtenerTodasSolicitudes(
        estado: _filtroEstado == 'todas' ? null : _filtroEstado,
      );
      setState(() {
        _solicitudes = list;
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Todas las Solicitudes (Auditoría)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros de Estado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _estados.map((st) {
                    final isSelected = (_filtroEstado == null && st == 'todas') || _filtroEstado == st;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          st.toUpperCase(),
                          style: CeosTheme.dataMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : context.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: CeosColors.areaOdontologia,
                        backgroundColor: context.cardBg,
                        side: BorderSide(
                          color: isSelected ? CeosColors.areaOdontologia : context.borderColor,
                        ),
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _filtroEstado = st == 'todas' ? null : st;
                          });
                          _cargarSolicitudes();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Lista Solo Lectura (HU-420)
            Expanded(
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
                                  onPressed: _cargarSolicitudes,
                                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _solicitudes.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron solicitudes con este filtro.',
                                style: CeosTheme.body(color: CeosColors.lightTextMuted),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargarSolicitudes,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _solicitudes.length,
                                itemBuilder: (context, index) {
                                  final sol = _solicitudes[index];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  sol.materialNombre,
                                                  style: CeosTheme.heading(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              BadgeEstado(estado: sol.estado),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${sol.cantidad} unidades • Solicitante: ${sol.usuarioNombre}',
                                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                                          ),
                                          Text(
                                            'Motivo: ${sol.motivo}',
                                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextMuted),
                                          ),
                                          if (sol.comentarioResolucion != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Resolución: ${sol.comentarioResolucion} (por: ${sol.resueltaPorNombre ?? "Gestor"})',
                                              style: CeosTheme.body(fontSize: 11, color: CeosColors.areaOdontologia),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
