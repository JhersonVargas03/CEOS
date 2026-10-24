import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/constants/icon_catalog.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/selector_area_modal.dart';
import '../../widgets/selector_icono_grid.dart';

class CrearEditarMaterialScreen extends ConsumerStatefulWidget {
  final int? materialId;
  final MaterialModel? material;
  final int? initialAreaId;
  final int? initialCategoriaId;

  const CrearEditarMaterialScreen({
    super.key,
    this.materialId,
    this.material,
    this.initialAreaId,
    this.initialCategoriaId,
  });

  @override
  ConsumerState<CrearEditarMaterialScreen> createState() => _CrearEditarMaterialScreenState();
}

class _CrearEditarMaterialScreenState extends ConsumerState<CrearEditarMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _unidadMedidaController = TextEditingController(text: 'unidades');
  final _stockMinimoController = TextEditingController(text: '5');
  final _diasAlertaController = TextEditingController(text: '30');
  final _descripcionController = TextEditingController();
  final _stockInicialController = TextEditingController(text: '0');

  int? _areaId;
  int? _categoriaId;
  String? _areaNombre;
  String? _categoriaNombre;
  String _categoriaIcono = 'package';
  bool _activo = true;
  bool _isLoading = false;
  bool _isInit = false;

  bool get _esEdicion => widget.materialId != null || widget.material != null;

  static const List<String> _presentacionesComunes = [
    'Unidad / Pieza',
    'Caja x 50 uds',
    'Caja x 100 uds',
    'Paquete x 20 uds',
    'Frasco x 500 ml',
    'Frasco x 1 L',
    'Ampolla x 5 ml',
    'Blíster x 10 comp',
    'Tubo x 100 g',
    'Rollo',
    'Kit completo',
  ];

  @override
  void initState() {
    super.initState();
    _areaId = widget.initialAreaId;
    _categoriaId = widget.initialCategoriaId;

    if (widget.material != null) {
      _cargarDatos(widget.material!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit && widget.material == null && widget.materialId != null) {
      _isInit = true;
      _buscarMaterial();
    }
  }

  void _cargarDatos(MaterialModel mat) {
    _nombreController.text = mat.nombre;
    _unidadMedidaController.text = mat.unidadMedida;
    _stockMinimoController.text = mat.stockMinimo.toString();
    _diasAlertaController.text = mat.diasAlertaCaducidad.toString();
    _areaId = mat.areaId;
    _categoriaId = mat.categoriaId;
    _areaNombre = mat.areaNombre;
    _categoriaNombre = mat.categoriaNombre;
    _categoriaIcono = mat.categoriaIcono;
    setState(() {});
  }

  Future<void> _buscarMaterial() async {
    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final mat = await repo.obtenerDetalleMaterial(widget.materialId!);
      if (mounted) {
        _cargarDatos(mat);
      }
    } catch (_) {
      final materiales = await ref.read(materialesAdminProvider.future);
      final encontrada = materiales.where((m) => m.id == widget.materialId).firstOrNull;
      if (encontrada != null && mounted) {
        _cargarDatos(encontrada);
      }
    }
  }

  Future<void> _seleccionarArea(BuildContext context, List<AreaModel> areas) async {
    final areaSeleccionada = await SelectorAreaModal.show(
      context: context,
      areas: areas,
      areaSeleccionadaId: _areaId,
    );

    if (areaSeleccionada != null && mounted) {
      setState(() {
        _areaId = areaSeleccionada.id;
        _areaNombre = areaSeleccionada.nombre;
        _categoriaId = null;
        _categoriaNombre = null;
      });
    }
  }

  Future<void> _seleccionarCategoria(BuildContext context, List<CategoriaModel> categorias) async {
    final catSeleccionada = await showModalBottomSheet<CategoriaModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categoriasDelArea = _areaId != null
                ? categorias.where((c) => c.areaId == null || c.areaId == _areaId).toList()
                : categorias;
            final filtradas = categoriasDelArea.where((c) {
              return c.nombre.toLowerCase().contains(query.toLowerCase());
            }).toList();

            final mediaQuery = MediaQuery.of(context);
            final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.top - 24;
            final modalHeight = (mediaQuery.size.height * 0.75).clamp(240.0, availableHeight > 240 ? availableHeight : 240.0);

            return Padding(
              padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
              child: Container(
                height: modalHeight,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(PhosphorIconsRegular.tag, size: 24, color: CeosColors.areaOdontologia),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Seleccionar Categoría',
                                    style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _mostrarDialogoCrearCategoria(context);
                          },
                          icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
                          label: const Text('Nueva'),
                          style: TextButton.styleFrom(
                            foregroundColor: CeosColors.areaOdontologia,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar categoría...',
                        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: CeosColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => query = val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtradas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(PhosphorIconsRegular.tag, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(
                                  'No se encontraron categorías',
                                  style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _mostrarDialogoCrearCategoria(context);
                                  },
                                  icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                                  label: const Text('Crear esta categoría'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: CeosColors.areaOdontologia,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filtradas.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                            itemBuilder: (context, i) {
                              final c = filtradas[i];
                              final isSelected = c.id == _categoriaId;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? CeosColors.areaOdontologia.withValues(alpha: 0.15)
                                      : CeosColors.lightBackground,
                                  child: Icon(
                                    IconCatalog.getIcon(c.icono),
                                    color: isSelected ? CeosColors.areaOdontologia : Colors.grey[700],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  c.nombre,
                                  style: CeosTheme.heading(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? CeosColors.areaOdontologia : null,
                                  ),
                                ),
                                subtitle: c.descripcion.isNotEmpty
                                    ? Text(
                                        c.descripcion,
                                        style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: isSelected
                                    ? const Icon(PhosphorIconsRegular.checkCircle, color: CeosColors.areaOdontologia)
                                    : null,
                                onTap: () => Navigator.pop(ctx, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

    if (catSeleccionada != null && mounted) {
      setState(() {
        _categoriaId = catSeleccionada.id;
        _categoriaNombre = catSeleccionada.nombre;
        _categoriaIcono = catSeleccionada.icono;
      });
    }
  }

  Future<void> _mostrarDialogoCrearCategoria(BuildContext context) async {
    if (_areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona primero un área antes de crear una categoría.'),
          backgroundColor: CeosColors.statusWarning,
        ),
      );
      return;
    }

    final nombreCatController = TextEditingController();
    final descCatController = TextEditingController();
    String iconoSeleccionado = 'tag';
    final formCatKey = GlobalKey<FormState>();
    bool guardandoCat = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(PhosphorIconsRegular.tag, color: CeosColors.areaOdontologia, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nueva Categoría', style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          _areaNombre != null ? 'Para área: $_areaNombre' : 'Asociada al área seleccionada',
                          style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Form(
                    key: formCatKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nombreCatController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la categoría *',
                            hintText: 'Ej. Anestésicos, Suturas...',
                            prefixIcon: Icon(PhosphorIconsRegular.tag, size: 20),
                          ),
                          autofocus: true,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'El nombre es obligatorio';
                            if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCatController,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                            hintText: 'Detalles de los materiales...',
                            prefixIcon: Icon(PhosphorIconsRegular.textT, size: 20),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Ícono:', style: CeosTheme.heading(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: CeosColors.areaOdontologia.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(IconCatalog.getIcon(iconoSeleccionado), size: 14, color: CeosColors.areaOdontologia),
                                  const SizedBox(width: 4),
                                  Text(
                                    iconoSeleccionado,
                                    style: CeosTheme.dataMono(
                                      fontSize: 11,
                                      color: CeosColors.areaOdontologia,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SelectorIconoGrid(
                              iconoSeleccionado: iconoSeleccionado,
                              onIconSelected: (ico) {
                                setDialogState(() => iconoSeleccionado = ico);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardandoCat ? null : () => Navigator.pop(dContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardandoCat
                      ? null
                      : () async {
                          if (!formCatKey.currentState!.validate()) return;
                          setDialogState(() => guardandoCat = true);
                          try {
                            final repo = ref.read(inventarioRepositoryProvider);
                            final nueva = await repo.crearCategoria(
                              nombre: nombreCatController.text.trim(),
                              descripcion: descCatController.text.trim(),
                              icono: iconoSeleccionado,
                              areaId: _areaId,
                            );
                            ref.invalidate(categoriasProvider(_areaId!));
                            if (mounted) {
                              setState(() {
                                _categoriaId = nueva.id;
                                _categoriaNombre = nueva.nombre;
                                _categoriaIcono = nueva.icono;
                              });
                            }
                            if (dContext.mounted) {
                              Navigator.pop(dContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Categoría "${nueva.nombre}" creada y seleccionada.'),
                                  backgroundColor: CeosColors.statusSuccess,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => guardandoCat = false);
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al crear categoría: $e'),
                                  backgroundColor: CeosColors.statusDanger,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CeosColors.areaOdontologia,
                    foregroundColor: Colors.white,
                  ),
                  child: guardandoCat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear y Seleccionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _unidadMedidaController.dispose();
    _stockMinimoController.dispose();
    _diasAlertaController.dispose();
    _descripcionController.dispose();
    _stockInicialController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_esEdicion && _areaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un área para el material'),
          backgroundColor: CeosColors.statusWarning,
        ),
      );
      return;
    }

    if (!_esEdicion && _categoriaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una categoría para el material'),
          backgroundColor: CeosColors.statusWarning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(inventarioRepositoryProvider);

    try {
      final stockMinimo = int.tryParse(_stockMinimoController.text.trim()) ?? 5;
      final diasAlerta = int.tryParse(_diasAlertaController.text.trim()) ?? 30;

      MaterialModel? materialCreado;
      if (_esEdicion) {
        final id = widget.material?.id ?? widget.materialId!;
        await repo.actualizarMaterial(
          id,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim().isNotEmpty
              ? _descripcionController.text.trim()
              : null,
          unidadMedida: _unidadMedidaController.text.trim(),
          stockMinimo: stockMinimo,
          activo: _activo,
        );
      } else {
        final stockInicial = int.tryParse(_stockInicialController.text.trim()) ?? 0;
        materialCreado = await repo.crearMaterial(
          nombre: _nombreController.text.trim(),
          areaId: _areaId!,
          categoriaId: _categoriaId!,
          stockMinimo: stockMinimo,
          diasAlertaCaducidad: diasAlerta,
          unidadMedida: _unidadMedidaController.text.trim(),
          // El backend crea el lote inicial de forma atómica
          stockInicial: stockInicial > 0 ? stockInicial : null,
        );
      }

      // Invalidar todos los proveedores de inventario relevantes
      ref.invalidate(materialesFiltradosProvider);
      ref.invalidate(materialesAdminProvider);
      ref.invalidate(areasProvider);
      ref.invalidate(alertasActivasProvider);
      ref.invalidate(categoriasProvider(null));
      if (_areaId != null) ref.invalidate(categoriasProvider(_areaId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _esEdicion ? 'Material actualizado con éxito' : 'Material registrado con éxito',
            ),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        if (context.canPop()) {
          context.pop(_esEdicion ? true : materialCreado);
        } else {
          context.go('/inventario');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar material: $e'),
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
    final areasAsync = ref.watch(areasProvider);
    final categoriasAsync = ref.watch(categoriasProvider(_areaId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/inventario'),
        ),
        title: Text(_esEdicion ? 'Editar Material' : 'Nuevo Material'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner if editing
                if (_esEdicion) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologia.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CeosColors.areaOdontologia.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          IconCatalog.getIcon(_categoriaIcono),
                          size: 28,
                          color: CeosColors.areaOdontologia,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _areaNombre != null && _areaNombre!.isNotEmpty
                                    ? 'Área: $_areaNombre'
                                    : 'Área asignada',
                                style: CeosTheme.heading(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _categoriaNombre != null && _categoriaNombre!.isNotEmpty
                                    ? 'Categoría: $_categoriaNombre'
                                    : 'Categoría asignada',
                                style: CeosTheme.body(
                                  fontSize: 12,
                                  color: CeosColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Fijo',
                            style: CeosTheme.dataMono(fontSize: 10, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Nombre del Material
                Text(
                  'Nombre del Material *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Gasas estériles 10x10, Guantes látex M...',
                    prefixIcon: Icon(PhosphorIconsRegular.cube, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor ingresa el nombre del material';
                    }
                    if (val.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Area Selector (only in create mode)
                if (!_esEdicion) ...[
                  Text(
                    'Área *',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  areasAsync.when(
                    data: (areas) {
                      final areaObj = areas.where((a) => a.id == _areaId).firstOrNull;
                      return InkWell(
                        onTap: () => _seleccionarArea(context, areas),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _areaId == null ? context.borderColor : CeosColors.areaOdontologia,
                              width: _areaId == null ? 1 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                areaObj != null
                                    ? IconCatalog.getIcon(areaObj.icono.isNotEmpty ? areaObj.icono : (areaObj.esOdontologia ? 'tooth' : 'sparkle'))
                                    : PhosphorIconsRegular.buildings,
                                size: 22,
                                color: areaObj != null
                                    ? (areaObj.esOdontologia ? CeosColors.areaOdontologia : CeosColors.areaEstetica)
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  areaObj?.nombre ?? 'Toca para buscar y seleccionar área...',
                                  style: CeosTheme.body(
                                    fontSize: 14,
                                    fontWeight: areaObj != null ? FontWeight.w600 : FontWeight.normal,
                                    color: areaObj != null ? context.textPrimary : context.textSecondary,
                                  ),
                                ),
                              ),
                              const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Error al cargar áreas: $err'),
                  ),
                  const SizedBox(height: 16),

                  // Categoria Selector (only in create mode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Categoría *',
                        style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (_areaId != null)
                        TextButton.icon(
                          onPressed: () => _mostrarDialogoCrearCategoria(context),
                          icon: const Icon(PhosphorIconsRegular.plusCircle, size: 16),
                          label: const Text('Nueva categoría', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: CeosColors.areaOdontologia,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_areaId == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.info, size: 20, color: context.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Selecciona primero un área para ver o crear sus categorías.',
                              style: CeosTheme.body(fontSize: 13, color: context.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    categoriasAsync.when(
                      data: (categorias) {
                        final catObj = categorias.where((c) => c.id == _categoriaId).firstOrNull;
                        return InkWell(
                          onTap: () => _seleccionarCategoria(context, categorias),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _categoriaId == null ? context.borderColor : CeosColors.areaOdontologia,
                                width: _categoriaId == null ? 1 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  catObj != null ? IconCatalog.getIcon(catObj.icono) : PhosphorIconsRegular.tag,
                                  size: 22,
                                  color: catObj != null ? CeosColors.areaOdontologia : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        catObj?.nombre ?? 'Toca para buscar y seleccionar categoría...',
                                        style: CeosTheme.body(
                                          fontSize: 14,
                                          fontWeight: catObj != null ? FontWeight.w600 : FontWeight.normal,
                                          color: catObj != null ? context.textPrimary : context.textSecondary,
                                        ),
                                      ),
                                      if (catObj?.descripcion != null && catObj!.descripcion.isNotEmpty)
                                        Text(
                                          catObj.descripcion,
                                          style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextSecondary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text('Error al cargar categorías: $err'),
                    ),
                  const SizedBox(height: 16),
                ],

                // Presentación (Unidad de Medida)
                Text(
                  'Presentación / Unidad de Empaque *',
                  style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Define el tipo de presentación y contenido (ej. "Caja x 100 uds", "Frasco x 500 ml", o "Unidad individual")',
                  style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _unidadMedidaController,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Caja x 100 uds, Frasco x 500ml, Unidad...',
                    prefixIcon: Icon(PhosphorIconsRegular.scales, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor especifica la presentación';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Quick chips for common packaging types with quantities
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presentacionesComunes.map((p) {
                    final isSelected = _unidadMedidaController.text.trim().toLowerCase() == p.toLowerCase();
                    return ChoiceChip(
                      label: Text(
                        p,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.white : context.textPrimary,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: CeosColors.areaOdontologia,
                      backgroundColor: context.cardBg,
                      side: BorderSide(
                        color: isSelected ? CeosColors.areaOdontologia : context.borderColor,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _unidadMedidaController.text = p);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Helper Explanatory Box for Issue #5
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: context.isDarkMode ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: context.isDarkMode ? 0.35 : 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(PhosphorIconsRegular.info, size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: CeosTheme.body(fontSize: 12, color: context.textPrimary),
                            children: const [
                              TextSpan(
                                text: '¿Cómo cuantifica el sistema el stock?\n',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: 'El stock registrado representa múltiplos de esta presentación. '
                                    'Si colocas ',
                              ),
                              TextSpan(
                                text: '"Caja x 100 uds"',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: ', tener un stock de 5 significa 5 cajas completas (500 piezas). '
                                    'Si en tu clínica prefieres descontar y contar pieza por pieza suelta, indica ',
                              ),
                              TextSpan(
                                text: '"Unidad / Pieza"',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stock Mínimo y Días Alerta en fila
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock Mínimo *',
                            style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _stockMinimoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              hintText: '5',
                              prefixIcon: Icon(PhosphorIconsRegular.warningCircle, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Requerido';
                              }
                              final n = int.tryParse(val.trim());
                              if (n == null || n < 0) return 'Inválido';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!_esEdicion) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Días Alerta Venc. *',
                              style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _diasAlertaController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                hintText: '30',
                                prefixIcon: Icon(PhosphorIconsRegular.clockCountdown, size: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                final n = int.tryParse(val.trim());
                                if (n == null || n <= 0) return 'Inválido';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Stock Inicial (solo en creación)
                if (!_esEdicion) ...[
                  Text(
                    'Stock Inicial (opcional)',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Si ya hay existencias, ingresa la cantidad para registrar la primera entrada',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _stockInicialController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '0',
                      prefixIcon: Icon(PhosphorIconsRegular.package, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Switch Activo/Inactivo (only in edit mode)
                if (_esEdicion) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Material Activo en Catálogo',
                        style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _activo
                            ? 'Disponible para solicitar y registrar entradas'
                            : 'Desactivado (no disponible para nuevos movimientos)',
                        style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                      ),
                      value: _activo,
                      activeThumbColor: CeosColors.areaOdontologia,
                      onChanged: (val) => setState(() => _activo = val),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Save Button
                const SizedBox(height: 16),
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
                        : (_esEdicion ? 'Actualizar Material' : 'Registrar Material'),
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
