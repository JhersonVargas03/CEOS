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

class CrearEditarCategoriaScreen extends ConsumerStatefulWidget {
  final int? categoriaId;
  final CategoriaModel? categoria;
  final int? initialAreaId;

  const CrearEditarCategoriaScreen({
    super.key,
    this.categoriaId,
    this.categoria,
    this.initialAreaId,
  });

  @override
  ConsumerState<CrearEditarCategoriaScreen> createState() => _CrearEditarCategoriaScreenState();
}

class _CrearEditarCategoriaScreenState extends ConsumerState<CrearEditarCategoriaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _iconoSeleccionado = 'package';
  int? _areaIdSeleccionada;
  bool _isLoading = false;
  bool _isInit = false;

  bool get _esEdicion => widget.categoriaId != null || widget.categoria != null;

  @override
  void initState() {
    super.initState();
    _areaIdSeleccionada = widget.initialAreaId;
    if (widget.categoria != null) {
      _cargarDatos(widget.categoria!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit && widget.categoria == null && widget.categoriaId != null) {
      _isInit = true;
      _buscarCategoria();
    }
  }

  void _cargarDatos(CategoriaModel cat) {
    _nombreController.text = cat.nombre;
    _descripcionController.text = cat.descripcion;
    _iconoSeleccionado = cat.icono.isNotEmpty ? cat.icono : 'package';
    _areaIdSeleccionada = cat.areaId ?? widget.initialAreaId;
    setState(() {});
  }

  Future<void> _buscarCategoria() async {
    final categorias = await ref.read(categoriasAdminProvider.future);
    final encontrada = categorias.where((c) => c.id == widget.categoriaId).firstOrNull;
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
        final id = widget.categoria?.id ?? widget.categoriaId!;
        await repo.actualizarCategoria(
          id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          icono: _iconoSeleccionado,
        );
      } else {
        await repo.crearCategoria(
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          icono: _iconoSeleccionado,
          areaId: _areaIdSeleccionada,
        );
      }

      ref.invalidate(categoriasProvider);
      ref.invalidate(categoriasAdminProvider);
      ref.invalidate(materialesFiltradosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _esEdicion ? 'Categoría actualizada con éxito' : 'Categoría creada con éxito',
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
            content: Text('Error al guardar categoría: $e'),
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
    final areasAsync = ref.watch(areasProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: Text(_esEdicion ? 'Editar Categoría' : 'Nueva Categoría'),
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
                                'Ícono de categoría',
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

                // Area Selection (only on creation, if areas exist)
                if (!_esEdicion) ...[
                  Text(
                    'Área (Opcional o Asignada)',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  areasAsync.when(
                    data: (areas) {
                      return DropdownButtonFormField<int?>(
                        value: _areaIdSeleccionada,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(PhosphorIconsRegular.buildings, size: 20),
                          hintText: 'Disponible para todas las áreas',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todas las áreas (General)'),
                          ),
                          ...areas.map((area) => DropdownMenuItem<int?>(
                                value: area.id,
                                child: Text(area.nombre),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _areaIdSeleccionada = val);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form Fields
                Text(
                  'Nombre de la Categoría *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Descartables, Farmacia, Anestesia...',
                    prefixIcon: Icon(PhosphorIconsRegular.tag, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor ingresa el nombre de la categoría';
                    }
                    if (val.trim().length < 2) {
                      return 'El nombre debe tener al menos 2 caracteres';
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
                    hintText: 'Describe los materiales que contiene...',
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
                        : (_esEdicion ? 'Actualizar Categoría' : 'Crear Categoría'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
