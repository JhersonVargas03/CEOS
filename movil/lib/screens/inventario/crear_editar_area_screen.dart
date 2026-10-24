import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/icon_catalog.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/selector_icono_grid.dart';

class CrearEditarAreaScreen extends ConsumerStatefulWidget {
  final int? areaId;
  final AreaModel? area;

  const CrearEditarAreaScreen({
    super.key,
    this.areaId,
    this.area,
  });

  @override
  ConsumerState<CrearEditarAreaScreen> createState() => _CrearEditarAreaScreenState();
}

class _CrearEditarAreaScreenState extends ConsumerState<CrearEditarAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _iconoSeleccionado = 'package';
  bool _isLoading = false;
  bool _isInit = false;

  bool get _esEdicion => widget.areaId != null || widget.area != null;

  @override
  void initState() {
    super.initState();
    if (widget.area != null) {
      _cargarDatos(widget.area!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit && widget.area == null && widget.areaId != null) {
      _isInit = true;
      _buscarArea();
    }
  }

  void _cargarDatos(AreaModel area) {
    _nombreController.text = area.nombre;
    _descripcionController.text = area.descripcion;
    _iconoSeleccionado = area.icono.isNotEmpty ? area.icono : 'package';
    setState(() {});
  }

  Future<void> _buscarArea() async {
    final areas = await ref.read(areasProvider.future);
    final encontrada = areas.where((a) => a.id == widget.areaId).firstOrNull;
    if (encontrada != null && mounted) {
      _cargarDatos(encontrada);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _abrirSelectorIcono() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Seleccionar Ícono',
                        style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(PhosphorIconsRegular.x),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SelectorIconoGrid(
                    iconoSeleccionado: _iconoSeleccionado,
                    onIconSelected: (icono) {
                      setState(() => _iconoSeleccionado = icono);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(inventarioRepositoryProvider);

    try {
      if (_esEdicion) {
        final id = widget.area?.id ?? widget.areaId!;
        await repo.actualizarArea(
          id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          icono: _iconoSeleccionado,
        );
      } else {
        await repo.crearArea(
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          icono: _iconoSeleccionado,
        );
      }

      ref.invalidate(areasProvider);
      ref.invalidate(materialesFiltradosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _esEdicion ? 'Área actualizada con éxito' : 'Área creada con éxito',
            ),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar área: $e'),
            backgroundColor: CeosColors.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconoData = IconCatalog.getIcon(_iconoSeleccionado);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: Text(_esEdicion ? 'Editar Área' : 'Nueva Área'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon Selector Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CeosColors.areaOdontologia.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            iconoData,
                            size: 28,
                            color: CeosColors.areaOdontologia,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ícono representativo',
                                style: CeosTheme.heading(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _iconoSeleccionado,
                                style: CeosTheme.dataMono(
                                  fontSize: 12,
                                  color: CeosColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _abrirSelectorIcono,
                          icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                          label: const Text('Cambiar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CeosColors.areaOdontologia,
                            side: const BorderSide(color: CeosColors.areaOdontologia),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Form Fields
                Text(
                  'Nombre del Área *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Odontología, Medicina General...',
                    prefixIcon: Icon(PhosphorIconsRegular.buildings, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor ingresa el nombre del área';
                    }
                    if (val.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Text(
                  'Descripción (Opcional)',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descripcionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe el propósito o alcance del área...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _guardar,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _esEdicion ? PhosphorIconsRegular.floppyDisk : PhosphorIconsRegular.check,
                          size: 20,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Guardando...'
                        : (_esEdicion ? 'Actualizar Área' : 'Crear Área'),
                    style: CeosTheme.heading(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CeosColors.areaOdontologia,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Botón Eliminar Área (solo en modo edición)
                if (_esEdicion) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CeosColors.statusDanger,
                      side: const BorderSide(color: CeosColors.statusDanger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                    label: const Text('Eliminar Área'),
                    onPressed: _isLoading ? null : _confirmarEliminarArea,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarArea() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Área?'),
        content: Text(
          'El área "${_nombreController.text}" será eliminada permanentemente. '
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final id = widget.area?.id ?? widget.areaId!;
        final repo = ref.read(inventarioRepositoryProvider);
        await repo.eliminarArea(id);
        ref.invalidate(areasProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Área eliminada correctamente.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
          context.pop(true);
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
        setState(() => _isLoading = false);
      }
    }
  }
}

