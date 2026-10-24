import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

class NuevaEntradaScreen extends ConsumerStatefulWidget {
  final int? initialMaterialId;

  const NuevaEntradaScreen({
    super.key,
    this.initialMaterialId,
  });

  @override
  ConsumerState<NuevaEntradaScreen> createState() => _NuevaEntradaScreenState();
}

class _NuevaEntradaScreenState extends ConsumerState<NuevaEntradaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _loteCodigoController = TextEditingController();
  final _costoController = TextEditingController();

  AreaModel? _areaSeleccionada;
  MaterialModel? _materialSeleccionado;
  DateTime? _fechaCaducidad;
  DateTime? _fechaAlerta;
  bool _isLoading = false;
  String? _errorMessage;

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
    _loteCodigoController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  // Sugerencia automática de fecha de alerta (-30 días de la caducidad) (HU-414)
  void _onFechaCaducidadSeleccionada(DateTime date) {
    setState(() {
      _fechaCaducidad = date;
      final suggested = date.subtract(Duration(days: _materialSeleccionado?.diasAlertaCaducidad ?? 30));
      _fechaAlerta = suggested.isAfter(DateTime.now()) ? suggested : DateTime.now();
    });
  }

  Future<void> _guardarEntrada() async {
    if (!_formKey.currentState!.validate()) return;

    if (_materialSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un material');
      return;
    }

    // Validación: fecha de alerta no posterior a la de caducidad (HU-414)
    if (_fechaCaducidad != null && _fechaAlerta != null && _fechaAlerta!.isAfter(_fechaCaducidad!)) {
      setState(() => _errorMessage = 'La fecha de alerta no puede ser posterior a la fecha de caducidad');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final fmt = DateFormat('yyyy-MM-dd');

      await repo.registrarEntrada(
        materialId: _materialSeleccionado!.id,
        cantidad: int.parse(_cantidadController.text.trim()),
        fechaCaducidad: _fechaCaducidad != null ? fmt.format(_fechaCaducidad!) : null,
        fechaAlerta: _fechaAlerta != null ? fmt.format(_fechaAlerta!) : null,
        costoUnitario: _costoController.text.trim().isNotEmpty
            ? double.tryParse(_costoController.text.trim())
            : null,
        numeroLote: _loteCodigoController.text.trim().isNotEmpty
            ? _loteCodigoController.text.trim()
            : 'Lote General',
      );

      // Refrescar catálogos de materiales e inventario
      ref.invalidate(materialesFiltradosProvider);
      ref.invalidate(materialesAdminProvider);
      ref.invalidate(alertasActivasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Entrada de ${_cantidadController.text} unidades de ${_materialSeleccionado!.nombre} registrada con éxito.',
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
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final areasAsync = ref.watch(areasProvider);
    final materialesAsync = ref.watch(materialesFiltradosProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Registrar Entrada de Lote'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
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

                // Selector de Material interactivo con buscador y creación
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
                                    : 'Seleccionar Material',
                                onCrearNuevo: () async {
                                  Navigator.pop(context);
                                  final nuevo = await context.push('/inventario/gestion/material/crear');
                                  if (nuevo is MaterialModel) {
                                    setState(() {
                                      _materialSeleccionado = nuevo;
                                      if (_areaSeleccionada == null || _areaSeleccionada!.id != nuevo.areaId) {
                                        final areas = ref.read(areasProvider).valueOrNull ?? [];
                                        _areaSeleccionada = areas.where((a) => a.id == nuevo.areaId).firstOrNull;
                                      }
                                    });
                                  }
                                },
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
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${materialesDelArea.length} materiales disponibles${_areaSeleccionada != null ? ' en ${_areaSeleccionada!.nombre}' : ''}',
                                style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final nuevo = await context.push('/inventario/gestion/material/crear');
                                  if (nuevo is MaterialModel) {
                                    setState(() {
                                      _materialSeleccionado = nuevo;
                                      if (_areaSeleccionada == null || _areaSeleccionada!.id != nuevo.areaId) {
                                        final areas = ref.read(areasProvider).valueOrNull ?? [];
                                        _areaSeleccionada = areas.where((a) => a.id == nuevo.areaId).firstOrNull;
                                      }
                                    });
                                  } else {
                                    ref.invalidate(materialesFiltradosProvider);
                                    ref.invalidate(materialesAdminProvider);
                                  }
                                },
                                icon: const Icon(PhosphorIconsRegular.plusCircle, size: 16),
                                label: const Text('Crear nuevo material'),
                                style: TextButton.styleFrom(
                                  foregroundColor: CeosColors.areaOdontologia,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error al cargar materiales: $e'),
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
                            setState(() => _materialSeleccionado = null);
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Cantidad Ingresada
                TextFormField(
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Cantidad a ingresar',
                    prefixIcon: const Icon(PhosphorIconsRegular.hash),
                    suffixText: _materialSeleccionado?.unidadMedida ?? 'unidades',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Ingresa la cantidad';
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Ingresa una cantidad válida mayor a 0';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Fecha de Caducidad (Opcional - HU-414 / Indumentaria / Insumos sin caducidad)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _fechaCaducidad == null
                        ? 'Fecha de Caducidad (opcional)'
                        : 'Caducidad: ${fmt.format(_fechaCaducidad!)}',
                    style: CeosTheme.body(
                      fontSize: 14,
                      fontWeight: _fechaCaducidad == null ? FontWeight.normal : FontWeight.bold,
                      color: _fechaCaducidad == null ? CeosColors.lightTextSecondary : null,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_fechaCaducidad != null)
                        IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18, color: CeosColors.lightTextSecondary),
                          tooltip: 'Quitar fecha',
                          onPressed: () {
                            setState(() {
                              _fechaCaducidad = null;
                              _fechaAlerta = null;
                            });
                          },
                        ),
                      const Icon(PhosphorIconsRegular.calendar, color: CeosColors.areaOdontologia),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fechaCaducidad ?? DateTime.now().add(const Duration(days: 90)),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) {
                      _onFechaCaducidadSeleccionada(picked);
                    }
                  },
                ),

                const SizedBox(height: 8),

                // Fecha de Alerta de Vencimiento (Sugerida, editable)
                if (_fechaCaducidad != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _fechaAlerta == null
                          ? 'Definir Fecha de Alerta'
                          : 'Fecha de Alerta: ${fmt.format(_fechaAlerta!)}',
                      style: CeosTheme.body(fontSize: 14),
                    ),
                    subtitle: Text(
                      'Sugerido: -30 días del vencimiento',
                      style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                    ),
                    trailing: const Icon(PhosphorIconsRegular.bell, color: CeosColors.statusWarning),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fechaAlerta ?? _fechaCaducidad!,
                        firstDate: DateTime.now(),
                        lastDate: _fechaCaducidad!,
                      );
                      if (picked != null) {
                        setState(() => _fechaAlerta = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],

                // Código o Número de Lote Opcional
                TextFormField(
                  controller: _loteCodigoController,
                  decoration: const InputDecoration(
                    labelText: 'Número / Código de Lote (opcional)',
                    hintText: 'ej. LOT-2026-A (o vacío para Lote General)',
                    helperText: 'Si se deja vacío, se asignará al Stock / Lote General',
                    prefixIcon: Icon(PhosphorIconsRegular.barcode),
                  ),
                ),

                const SizedBox(height: 16),

                // Costo Unitario Opcional
                TextFormField(
                  controller: _costoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario (opcional)',
                    prefixIcon: Icon(PhosphorIconsRegular.currencyDollar),
                  ),
                  validator: (val) {
                    if (val != null && val.trim().isNotEmpty) {
                      final c = double.tryParse(val.trim());
                      if (c == null || c < 0) return 'El costo debe ser un número mayor o igual a 0';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isLoading ? null : _guardarEntrada,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Registrar Entrada'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
