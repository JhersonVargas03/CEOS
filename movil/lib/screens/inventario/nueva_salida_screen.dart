import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/icon_catalog.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/permisos_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/selector_area_modal.dart';
import '../../widgets/selector_material_modal.dart';

class NuevaSalidaScreen extends ConsumerStatefulWidget {
  final int? initialMaterialId;

  const NuevaSalidaScreen({
    super.key,
    this.initialMaterialId,
  });

  @override
  ConsumerState<NuevaSalidaScreen> createState() => _NuevaSalidaScreenState();
}

class _NuevaSalidaScreenState extends ConsumerState<NuevaSalidaScreen> {
  final _cantidadController = TextEditingController();
  final _motivoController = TextEditingController();
  AreaModel? _areaSeleccionada;
  MaterialModel? _materialSeleccionado;
  bool _enRevision = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _errorPorStockInsuficiente = false;

  @override
  void initState() {
    super.initState();
    _initMaterial();
  }

  Future<void> _initMaterial() async {
    final areas = await ref.read(areasProvider.future);
    if (widget.initialMaterialId != null) {
      try {
        final repo = ref.read(inventarioRepositoryProvider);
        final mat = await repo.obtenerDetalleMaterial(widget.initialMaterialId!);
        setState(() {
          _materialSeleccionado = mat;
          _areaSeleccionada = areas.where((a) => a.id == mat.areaId).firstOrNull;
        });
      } catch (_) {}
    } else {
      final globalArea = ref.read(areaSeleccionadaProvider);
      if (globalArea != null && mounted) {
        setState(() => _areaSeleccionada = globalArea);
      }
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  void _irARevision() {
    if (_materialSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un material');
      return;
    }

    final cant = int.tryParse(_cantidadController.text.trim());
    if (cant == null || cant <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad válida');
      return;
    }

    if (cant > _materialSeleccionado!.stockTotal) {
      setState(() {
        _errorMessage = 'No hay suficiente stock digital (disponible: ${_materialSeleccionado!.stockTotal} ${_materialSeleccionado!.unidadMedida}).';
        _errorPorStockInsuficiente = true;
      });
      return;
    }

    setState(() {
      _enRevision = true;
      _errorMessage = null;
      _errorPorStockInsuficiente = false;
    });
  }

  Future<void> _confirmarSalida() async {
    if (_isLoading || _materialSeleccionado == null) return;

    final cant = int.tryParse(_cantidadController.text.trim());
    if (cant == null || cant <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad válida');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorPorStockInsuficiente = false;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);

      await repo.registrarSalida(
        materialId: _materialSeleccionado!.id,
        cantidad: cant,
        motivo: _motivoController.text.trim().isNotEmpty
            ? _motivoController.text.trim()
            : 'Uso en atención clínica',
      );

      // Refrescar inventario y alertas
      ref.invalidate(materialesFiltradosProvider);
      ref.invalidate(materialesAdminProvider);
      ref.invalidate(alertasActivasProvider);

      if (mounted) {
        // Mensaje de éxito simple sin datos de lote (HU-415)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Salida de $cant ${_materialSeleccionado!.unidadMedida} de ${_materialSeleccionado!.nombre} registrada.',
            ),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/inventario');
        }
      }
    } on AppException catch (e) {
      final isStockErr = e.message.toLowerCase().contains('stock') ||
          e.message.toLowerCase().contains('insuficiente');

      setState(() {
        _errorMessage = e.message;
        _errorPorStockInsuficiente = isStockErr;
        _isLoading = false;
        _enRevision = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _enRevision = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(areasProvider);
    final materialesAsync = ref.watch(materialesFiltradosProvider);
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);

    final puedeAjustar = esSuperadmin ||
        permisosAsync.maybeWhen(
          data: (p) => p.contains('ajustar_inventario'),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: Text(_enRevision ? 'Revisión de Salida' : 'Registrar Salida'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CeosColors.statusDangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.statusDanger.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(PhosphorIconsFill.warningCircle, color: CeosColors.statusDanger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger),
                            ),
                          ),
                        ],
                      ),
                      // Botón condicional "Hacer Ajuste" tras stock insuficiente (HU-415)
                      if (_errorPorStockInsuficiente && puedeAjustar && _materialSeleccionado != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: CeosColors.statusDanger),
                            icon: const Icon(PhosphorIconsRegular.slidersHorizontal, size: 16),
                            label: const Text('Hacer Ajuste de Inventario'),
                            onPressed: () {
                              context.push('/inventario/ajuste?materialId=${_materialSeleccionado!.id}');
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!_enRevision) ...[
                // T-AJUSTE-MV.46: Paso 1: Selección de Área y Material
                Text(
                  'Área *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                areasAsync.when(
                  data: (areas) {
                    final isOdonto = _areaSeleccionada?.esOdontologia ?? true;
                    final areaColor = isOdonto ? CeosColors.areaOdontologia : CeosColors.areaEstetica;
                    return InkWell(
                      onTap: () async {
                        final area = await SelectorAreaModal.show(
                          context: context,
                          areas: areas,
                          areaSeleccionadaId: _areaSeleccionada?.id,
                        );
                        if (area != null) {
                          setState(() {
                            _areaSeleccionada = area;
                            if (_materialSeleccionado != null && _materialSeleccionado!.areaId != area.id) {
                              _materialSeleccionado = null;
                              _cantidadController.clear();
                              _errorPorStockInsuficiente = false;
                            }
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _areaSeleccionada != null ? areaColor : context.borderColor,
                            width: _areaSeleccionada != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _areaSeleccionada != null
                                  ? IconCatalog.getIcon(_areaSeleccionada!.icono.isNotEmpty ? _areaSeleccionada!.icono : (isOdonto ? 'tooth' : 'sparkle'))
                                  : PhosphorIconsRegular.buildings,
                              size: 22,
                              color: _areaSeleccionada != null ? areaColor : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _areaSeleccionada?.nombre ?? 'Selecciona un área para filtrar materiales...',
                                style: CeosTheme.body(
                                  fontSize: 14,
                                  fontWeight: _areaSeleccionada != null ? FontWeight.w600 : FontWeight.normal,
                                  color: _areaSeleccionada != null ? context.textPrimary : context.textSecondary,
                                ),
                              ),
                            ),
                            const Icon(PhosphorIconsRegular.caretDown, size: 18, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error al cargar áreas: $e'),
                ),
                const SizedBox(height: 16),

                Text(
                  'Material *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_materialSeleccionado == null)
                  materialesAsync.when(
                    data: (materiales) {
                      final conStock = materiales.where((m) {
                        final cumpleArea = _areaSeleccionada == null || m.areaId == _areaSeleccionada!.id;
                        return cumpleArea && m.stockTotal > 0;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () async {
                              final mat = await SelectorMaterialModal.show(
                                context: context,
                                materiales: materiales,
                                areaId: _areaSeleccionada?.id,
                                titulo: _areaSeleccionada != null
                                    ? 'Materiales con Stock de ${_areaSeleccionada!.nombre}'
                                    : 'Seleccionar Material para Salida',
                                soloConStock: true,
                              );
                              if (mat != null) {
                                setState(() {
                                  _materialSeleccionado = mat;
                                  if (_areaSeleccionada == null || _areaSeleccionada!.id != mat.areaId) {
                                    final areas = ref.read(areasProvider).valueOrNull ?? [];
                                    _areaSeleccionada = areas.where((a) => a.id == mat.areaId).firstOrNull;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIconsRegular.magnifyingGlass, color: CeosColors.areaOdontologia),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _areaSeleccionada != null
                                          ? 'Buscar o seleccionar material con stock en ${_areaSeleccionada!.nombre}...'
                                          : 'Buscar o seleccionar material con stock...',
                                      style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                                    ),
                                  ),
                                  const Icon(PhosphorIconsRegular.caretDown, size: 16, color: CeosColors.lightTextMuted),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${conStock.length} materiales con stock disponible${_areaSeleccionada != null ? ' en ${_areaSeleccionada!.nombre}' : ''}',
                            style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologiaLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CeosColors.areaOdontologia.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsFill.package, color: CeosColors.areaOdontologia),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _materialSeleccionado!.nombre,
                                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_materialSeleccionado!.areaNombre} • Disponible: ${_materialSeleccionado!.stockTotal} ${_materialSeleccionado!.unidadMedida}',
                                style: CeosTheme.dataMono(
                                  fontSize: 12,
                                  color: CeosColors.areaOdontologia,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          tooltip: 'Cambiar material',
                          onPressed: () {
                            setState(() => _materialSeleccionado = null);
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                TextField(
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad a retirar',
                    prefixIcon: const Icon(PhosphorIconsRegular.hash),
                    suffixText: _materialSeleccionado?.unidadMedida ?? 'unidades',
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Uso clínico (opcional)',
                    hintText: 'ej. Tratamiento conducto Box 2',
                    prefixIcon: Icon(PhosphorIconsRegular.notePencil),
                  ),
                ),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _irARevision,
                  child: const Text('Revisar y Confirmar'),
                ),
              ] else ...[
                // Paso 2: Pantalla de Revisión Simple (HU-415)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.arrowSquareOut,
                        size: 40,
                        color: CeosColors.areaOdontologia,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Vas a registrar la salida de:',
                        style: CeosTheme.body(fontSize: 14, color: CeosColors.lightTextSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_cantidadController.text} ${_materialSeleccionado!.unidadMedida}',
                        style: CeosTheme.dataMono(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: CeosColors.areaOdontologia,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _materialSeleccionado!.nombre,
                        style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'El descuento se realizará automáticamente por orden de vencimiento (FEFO).',
                        style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => setState(() => _enRevision = false),
                        child: const Text('Modificar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirmarSalida,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
