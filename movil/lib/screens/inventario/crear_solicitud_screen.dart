import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/selector_area.dart';
import '../../widgets/selector_material_modal.dart';

class CrearSolicitudScreen extends ConsumerStatefulWidget {
  final int? initialMaterialId;

  const CrearSolicitudScreen({
    super.key,
    this.initialMaterialId,
  });

  @override
  ConsumerState<CrearSolicitudScreen> createState() => _CrearSolicitudScreenState();
}

class _CrearSolicitudScreenState extends ConsumerState<CrearSolicitudScreen> {
  final _cantidadController = TextEditingController();
  final _comentarioController = TextEditingController();
  final _nombreNuevoMaterialController = TextEditingController();
  final _unidadMedidaController = TextEditingController(text: 'unidades');

  bool _esNuevoMaterial = false;
  int? _areaDestinoId;
  MaterialModel? _materialSeleccionado;
  String _motivo = 'Sin stock disponible';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _catalogoMotivos = [
    'Sin stock disponible',
    'Reposición preventiva (baja rotación)',
    'Aumento de demanda en cirugías',
    'Material próximo a vencer',
    'Nuevo material o insumo requerido',
    'Otro motivo',
  ];

  @override
  void initState() {
    super.initState();
    _initMaterial();
  }

  Future<void> _initMaterial() async {
    if (widget.initialMaterialId != null) {
      try {
        final repo = ref.read(inventarioRepositoryProvider);
        final mat = await repo.obtenerDetalleMaterial(widget.initialMaterialId!);
        _onMaterialSelected(mat);
      } catch (_) {}
    }
  }

  // Sugerencia automática de motivo según stock (HU-417)
  void _onMaterialSelected(MaterialModel mat) {
    setState(() {
      _materialSeleccionado = mat;
      if (mat.stockTotal <= 0) {
        _motivo = 'Sin stock disponible';
      } else {
        _motivo = 'Reposición preventiva (baja rotación)';
      }
    });
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _comentarioController.dispose();
    _nombreNuevoMaterialController.dispose();
    _unidadMedidaController.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    if (_isLoading) return;
    if (!_esNuevoMaterial && _materialSeleccionado == null) {
      setState(() => _errorMessage = 'Selecciona un material o activa la opción de nuevo material');
      return;
    }

    if (_esNuevoMaterial && _nombreNuevoMaterialController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Ingresa el nombre del nuevo material a solicitar');
      return;
    }

    final cant = int.tryParse(_cantidadController.text.trim());
    if (cant == null || cant <= 0) {
      setState(() => _errorMessage = 'Ingresa una cantidad válida a solicitar');
      return;
    }

    final areaActual = _areaDestinoId ?? ref.read(areaSeleccionadaProvider)?.id;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);

      if (_esNuevoMaterial) {
        final nombreNuevo = _nombreNuevoMaterialController.text.trim();
        final unidad = _unidadMedidaController.text.trim().isNotEmpty
            ? _unidadMedidaController.text.trim()
            : 'unidades';

        await repo.crearSolicitud(
          nombreMaterialNuevo: nombreNuevo,
          areaId: areaActual,
          unidadMedida: unidad,
          cantidad: cant,
          motivo: _motivo,
          comentario: _comentarioController.text.trim().isNotEmpty
              ? _comentarioController.text.trim()
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solicitud para nuevo material "$nombreNuevo" ($cant $unidad) enviada exitosamente.',
              ),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/inventario/solicitudes');
          }
        }
      } else {
        await repo.crearSolicitud(
          materialId: _materialSeleccionado!.id,
          cantidad: cant,
          motivo: _motivo,
          comentario: _comentarioController.text.trim().isNotEmpty
              ? _comentarioController.text.trim()
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solicitud de $cant ${_materialSeleccionado!.unidadMedida} de ${_materialSeleccionado!.nombre} enviada.',
              ),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/inventario/solicitudes');
          }
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
    final materialesAsync = ref.watch(materialesFiltradosProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: const Text('Crear Solicitud de Material'),
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

              // Selector de Área (HU-417)
              const SelectorArea(),
              const SizedBox(height: 16),

              // Toggle: Material existente vs Nuevo material no registrado
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _esNuevoMaterial
                      ? CeosColors.areaOdontologiaLight
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _esNuevoMaterial
                        ? CeosColors.areaOdontologia
                        : Colors.grey.withValues(alpha: 0.25),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    '¿Material no registrado en catálogo?',
                    style: CeosTheme.heading(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _esNuevoMaterial ? CeosColors.areaOdontologia : null,
                    ),
                  ),
                  subtitle: Text(
                    _esNuevoMaterial
                        ? 'Ingresa el nombre y área del nuevo material a solicitar'
                        : 'Activa si necesitas un insumo que no aparece en la lista',
                    style: CeosTheme.body(
                      fontSize: 12,
                      color: CeosColors.lightTextSecondary,
                    ),
                  ),
                  value: _esNuevoMaterial,
                  activeColor: CeosColors.areaOdontologia,
                  onChanged: (val) {
                    setState(() {
                      _esNuevoMaterial = val;
                      if (val) {
                        _materialSeleccionado = null;
                        _motivo = 'Nuevo material o insumo requerido';
                      } else {
                        _motivo = 'Sin stock disponible';
                      }
                    });
                  },
                ),
              ),

              // Campos según tipo de material
              if (_esNuevoMaterial) ...[
                TextField(
                  controller: _nombreNuevoMaterialController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del nuevo material *',
                    hintText: 'Ej. Resina Fotocurable A2, Guantes de Nitrilo...',
                    prefixIcon: Icon(PhosphorIconsRegular.pencilSimple),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _unidadMedidaController,
                  decoration: const InputDecoration(
                    labelText: 'Presentación *',
                    hintText: 'ej. cajas, unidades, paquetes, frascos, tubos',
                    helperText: 'Indica cómo viene presentado el material (caja, frasco, bolsa...)',
                    prefixIcon: Icon(PhosphorIconsRegular.package),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else if (_materialSeleccionado == null)
                materialesAsync.when(
                  data: (materiales) {
                    if (materiales.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsRegular.package, color: CeosColors.lightTextSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No hay materiales en el área seleccionada.',
                                style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () async {
                            final mat = await SelectorMaterialModal.show(
                              context: context,
                              materiales: materiales,
                              titulo: 'Seleccionar Material para Solicitud',
                            );
                            if (mat != null) {
                              _onMaterialSelected(mat);
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
                                    'Buscar o seleccionar material...',
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
                          '${materiales.length} materiales disponibles en el área',
                          style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: CeosColors.statusDangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CeosColors.statusDanger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.warningCircle, color: CeosColors.statusDanger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error al cargar materiales.',
                            style: CeosTheme.body(fontSize: 12, color: CeosColors.statusDanger),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.refresh(materialesFiltradosProvider),
                          child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
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
                              'Stock actual: ${_materialSeleccionado!.stockTotal} ${_materialSeleccionado!.unidadMedida}',
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
                        icon: const Icon(PhosphorIconsRegular.xCircle, color: CeosColors.areaOdontologia),
                        tooltip: 'Cambiar material',
                        onPressed: () => setState(() => _materialSeleccionado = null),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Cantidad
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad solicitada *',
                  prefixIcon: const Icon(PhosphorIconsRegular.hash),
                  suffixText: _esNuevoMaterial
                      ? (_unidadMedidaController.text.isNotEmpty
                          ? _unidadMedidaController.text
                          : 'unidades')
                      : (_materialSeleccionado?.unidadMedida ?? 'unidades'),
                ),
              ),

              const SizedBox(height: 16),

              // Motivo (con sugerencia automática) (HU-417)
              DropdownButtonFormField<String>(
                value: _motivo,
                decoration: const InputDecoration(
                  labelText: 'Motivo de reposición *',
                  prefixIcon: Icon(PhosphorIconsRegular.notePencil),
                ),
                items: _catalogoMotivos.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _motivo = val);
                },
              ),

              const SizedBox(height: 16),

              // Comentario opcional
              TextField(
                controller: _comentarioController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario / Justificación adicional (opcional)',
                  prefixIcon: Icon(PhosphorIconsRegular.chatCircleText),
                ),
              ),

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _isLoading ? null : _enviarSolicitud,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Enviar Solicitud'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
