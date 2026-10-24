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
import '../../providers/storage_provider.dart';
import '../../widgets/selector_area_modal.dart';
import '../../widgets/selector_material_modal.dart';

class AjusteInventarioScreen extends ConsumerStatefulWidget {
  final int? initialMaterialId;

  const AjusteInventarioScreen({
    super.key,
    this.initialMaterialId,
  });

  @override
  ConsumerState<AjusteInventarioScreen> createState() => _AjusteInventarioScreenState();
}

class _AjusteInventarioScreenState extends ConsumerState<AjusteInventarioScreen> {
  final _cantidadNuevaController = TextEditingController();
  final _motivoOtroController = TextEditingController();

  AreaModel? _areaSeleccionada;
  MaterialModel? _materialSeleccionado;
  List<LoteModel> _lotes = [];
  LoteModel? _loteSeleccionado;
  String _motivoSeleccionado = 'Diferencia en conteo físico';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _catalogoMotivos = [
    'Diferencia en conteo físico',
    'Material dañado o roto',
    'Caducidad anticipada',
    'Error de digitación anterior',
    'Otro (especificar)',
  ];

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
        final lotes = await repo.obtenerLotesMaterial(widget.initialMaterialId!);
        setState(() {
          _materialSeleccionado = mat;
          _areaSeleccionada = areas.where((a) => a.id == mat.areaId).firstOrNull;
          _lotes = lotes;
          if (lotes.isNotEmpty) {
            _loteSeleccionado = lotes.first;
            _cantidadNuevaController.text = lotes.first.cantidad.toString();
          }
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
    _cantidadNuevaController.dispose();
    _motivoOtroController.dispose();
    super.dispose();
  }

  Future<void> _onMaterialChanged(MaterialModel mat) async {
    setState(() {
      _materialSeleccionado = mat;
      _loteSeleccionado = null;
      _lotes = [];
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final lotes = await repo.obtenerLotesMaterial(mat.id);
      setState(() {
        _lotes = lotes;
        if (lotes.isNotEmpty) {
          _loteSeleccionado = lotes.first;
          _cantidadNuevaController.text = lotes.first.cantidad.toString();
        }
      });
    } catch (_) {}
  }

  void _solicitarConfirmacion() {
    if (_materialSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un material');
      return;
    }

    if (_lotes.isNotEmpty && _loteSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un lote para ajustar');
      return;
    }

    final nuevaCant = int.tryParse(_cantidadNuevaController.text.trim());
    if (nuevaCant == null || nuevaCant < 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad nueva válida (>= 0)');
      return;
    }

    final motivoFinal = _motivoSeleccionado == 'Otro (especificar)'
        ? _motivoOtroController.text.trim()
        : _motivoSeleccionado;

    if (motivoFinal.isEmpty) {
      setState(() => _errorMessage = 'El motivo del ajuste es obligatorio');
      return;
    }

    final loteNombre = _loteSeleccionado != null
        ? _loteSeleccionado!.numeroLote
        : 'Lote General (Inicial)';
    final stockPrevio = _loteSeleccionado != null
        ? _loteSeleccionado!.cantidad
        : _materialSeleccionado!.stockTotal;

    // Modal de Confirmación Explícita (HU-416)
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Ajuste Manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Confirmas cambiar el stock de este material?'),
              const SizedBox(height: 12),
              Text(
                'Lote / Destino: $loteNombre',
                style: CeosTheme.dataMono(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Stock anterior: $stockPrevio unidades'),
              Text(
                'Stock nuevo: $nuevaCant unidades',
                style: CeosTheme.body(fontWeight: FontWeight.bold, color: CeosColors.areaOdontologia),
              ),
              const SizedBox(height: 8),
              Text('Motivo: $motivoFinal', style: CeosTheme.body(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusWarning),
            onPressed: () {
              Navigator.pop(ctx);
              _ejecutarAjuste(nuevaCant, motivoFinal);
            },
            child: const Text('Confirmar Ajuste'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarAjuste(int nuevaCantidad, String motivo) async {
    if (_isLoading || _materialSeleccionado == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      await repo.registrarAjuste(
        loteId: _loteSeleccionado?.id,
        materialId: _materialSeleccionado!.id,
        cantidadNueva: nuevaCantidad,
        motivo: motivo,
      );

      // Refrescar inventario y alertas
      ref.invalidate(materialesFiltradosProvider);
      ref.invalidate(materialesAdminProvider);
      ref.invalidate(alertasActivasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajuste de inventario guardado correctamente.'),
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
      setState(() {
        _errorMessage = e.message;
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
    final areasAsync = ref.watch(areasProvider);
    final materialesAsync = ref.watch(materialesFiltradosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Ajuste Manual de Inventario'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CeosColors.statusDangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.statusDanger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // T-AJUSTE-MV.46: Selector de Área interactivo
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
                            _loteSeleccionado = null;
                            _lotes = [];
                            _cantidadNuevaController.clear();
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

              // Material
              Text(
                'Material *',
                style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_materialSeleccionado == null)
                materialesAsync.when(
                  data: (materiales) {
                    final materialesDelArea = _areaSeleccionada != null
                        ? materiales.where((m) => m.areaId == _areaSeleccionada!.id).toList()
                        : materiales;

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
                                  ? 'Materiales de ${_areaSeleccionada!.nombre}'
                                  : 'Seleccionar Material para Ajuste',
                            );
                            if (mat != null) {
                              _onMaterialChanged(mat);
                              if (_areaSeleccionada == null || _areaSeleccionada!.id != mat.areaId) {
                                final areas = ref.read(areasProvider).valueOrNull ?? [];
                                setState(() {
                                  _areaSeleccionada = areas.where((a) => a.id == mat.areaId).firstOrNull;
                                });
                              }
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
                                        ? 'Buscar o seleccionar material en ${_areaSeleccionada!.nombre}...'
                                        : 'Buscar o seleccionar material...',
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
                          '${materialesDelArea.length} materiales disponibles${_areaSeleccionada != null ? ' en ${_areaSeleccionada!.nombre}' : ''}',
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
                    border: Border.all(color: CeosColors.areaOdontologia.withValues(alpha: 0.3)),
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
                              '${_materialSeleccionado!.areaNombre} • Stock actual: ${_materialSeleccionado!.stockTotal} ${_materialSeleccionado!.unidadMedida}',
                              style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.x, size: 18),
                        tooltip: 'Cambiar material',
                        onPressed: () {
                          setState(() {
                            _materialSeleccionado = null;
                            _loteSeleccionado = null;
                            _lotes = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Selector / Información de Lote
              if (_materialSeleccionado != null && _lotes.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CeosColors.areaOdontologiaLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.areaOdontologia.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.info, color: CeosColors.areaOdontologia, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Este material no tiene lotes previos. El ajuste creará/actualizará el "Lote General" con el stock ingresado.',
                          style: CeosTheme.body(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_lotes.length == 1) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsRegular.barcode, color: CeosColors.areaOdontologia, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lote: ${_loteSeleccionado?.numeroLote ?? "Lote General"}',
                              style: CeosTheme.dataMono(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Stock actual: ${_loteSeleccionado?.cantidad ?? 0} unidades',
                              style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_lotes.length > 1) ...[
                DropdownButtonFormField<LoteModel>(
                  initialValue: _loteSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar Lote a Ajustar',
                    prefixIcon: Icon(PhosphorIconsRegular.barcode),
                  ),
                  items: _lotes.map((l) {
                    return DropdownMenuItem(
                      value: l,
                      child: Text('${l.numeroLote} (actual: ${l.cantidad} un. • ${l.fechaCaducidad != null && l.fechaCaducidad!.isNotEmpty ? "vence: ${l.fechaCaducidad}" : "sin caducidad"})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _loteSeleccionado = val;
                      if (val != null) {
                        _cantidadNuevaController.text = val.cantidad.toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Cantidad Nueva
              TextField(
                controller: _cantidadNuevaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nueva cantidad real en stock',
                  prefixIcon: Icon(PhosphorIconsRegular.hash),
                ),
              ),

              const SizedBox(height: 16),

              // Motivo Obligatorio (HU-416)
              DropdownButtonFormField<String>(
                initialValue: _motivoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Motivo del ajuste *',
                  prefixIcon: Icon(PhosphorIconsRegular.notePencil),
                ),
                items: _catalogoMotivos.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _motivoSeleccionado = val);
                },
              ),

              if (_motivoSeleccionado == 'Otro (especificar)') ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _motivoOtroController,
                  decoration: const InputDecoration(
                    labelText: 'Especifica el motivo en detalle *',
                    prefixIcon: Icon(PhosphorIconsRegular.textT),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusWarning),
                onPressed: _isLoading ? null : _solicitarConfirmacion,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Revisar y Guardar Ajuste'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
