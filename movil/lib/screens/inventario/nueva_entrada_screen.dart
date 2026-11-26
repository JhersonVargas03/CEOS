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
import '../../widgets/escaner_codigo_barras_modal.dart';

enum _ModoEntrada {
  seleccionar, // Paso A: buscar o escanear material
  loteExistente, // Paso B1: material existente -> solo datos del lote
  crearYEntrar, // Paso B2: material nuevo + primer lote en 1 paso
}

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

  // Paso A: Búsqueda
  final _searchController = TextEditingController();
  int? _filtroAreaId;
  bool _buscandoCodigo = false;
  String? _bannerInfo;

  // Estado del flujo
  _ModoEntrada _modo = _ModoEntrada.seleccionar;
  MaterialModel? _materialSeleccionado;

  // Paso B2: Campos de nuevo material
  final _nombreController = TextEditingController();
  final _codigoBarrasController = TextEditingController();
  final _unidadController = TextEditingController(text: 'unidad');
  final _stockMinimoController = TextEditingController(text: '5');
  AreaModel? _areaNueva;
  CategoriaModel? _categoriaNueva;

  // Campos de lote (comunes a B1 y B2)
  final _cantidadController = TextEditingController();
  final _loteCodigoController = TextEditingController();
  final _costoController = TextEditingController();
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
    if (!mounted) return;

    if (widget.initialMaterialId != null) {
      try {
        final repo = ref.read(inventarioRepositoryProvider);
        final mat = await repo.obtenerDetalleMaterial(widget.initialMaterialId!);
        if (!mounted) return;
        setState(() {
          _materialSeleccionado = mat;
          _modo = _ModoEntrada.loteExistente;
        });
        return;
      } catch (_) {}
    }

    final globalArea = ref.read(areaSeleccionadaProvider);
    if (globalArea != null && mounted) {
      setState(() {
        _filtroAreaId = globalArea.id;
        _areaNueva = globalArea;
      });
    } else if (areas.isNotEmpty && mounted) {
      setState(() {
        _areaNueva = areas.first;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nombreController.dispose();
    _codigoBarrasController.dispose();
    _unidadController.dispose();
    _stockMinimoController.dispose();
    _cantidadController.dispose();
    _loteCodigoController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  // Sugerencia automática de fecha de alerta (-30 días de la caducidad) (HU-414)
  void _onFechaCaducidadSeleccionada(DateTime date) {
    setState(() {
      _fechaCaducidad = date;
      final dias = _materialSeleccionado?.diasAlertaCaducidad ?? 30;
      final suggested = date.subtract(Duration(days: dias));
      _fechaAlerta = suggested.isAfter(DateTime.now()) ? suggested : DateTime.now();
    });
  }

  Future<void> _escanearEnBuscador() async {
    final codigo = await EscanerCodigoBarrasModal.abrir(context);
    if (codigo == null || codigo.isEmpty || !mounted) return;

    setState(() {
      _buscandoCodigo = true;
      _errorMessage = null;
      _bannerInfo = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final encontrado = await repo.buscarMaterialPorCodigoBarras(codigo);
      if (!mounted) return;

      if (encontrado != null) {
        setState(() {
          _materialSeleccionado = encontrado;
          _modo = _ModoEntrada.loteExistente;
          _bannerInfo = 'Material encontrado por código de barras ($codigo).';
        });
      } else {
        _iniciarCreacionMaterial(codigoBarras: codigo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error al consultar código de barras: $e');
      }
    } finally {
      if (mounted) setState(() => _buscandoCodigo = false);
    }
  }

  Future<void> _escanearParaCampoNuevo() async {
    final codigo = await EscanerCodigoBarrasModal.abrir(context);
    if (codigo == null || codigo.isEmpty || !mounted) return;
    setState(() {
      _codigoBarrasController.text = codigo;
    });
  }

  void _seleccionarMaterialExistente(MaterialModel mat) {
    setState(() {
      _materialSeleccionado = mat;
      _modo = _ModoEntrada.loteExistente;
      _errorMessage = null;
      _bannerInfo = null;
    });
  }

  void _iniciarCreacionMaterial({String? nombreInicial, String? codigoBarras}) {
    setState(() {
      _materialSeleccionado = null;
      _modo = _ModoEntrada.crearYEntrar;
      _errorMessage = null;
      if (nombreInicial != null && nombreInicial.trim().isNotEmpty) {
        _nombreController.text = nombreInicial.trim();
      }
      if (codigoBarras != null && codigoBarras.trim().isNotEmpty) {
        _codigoBarrasController.text = codigoBarras.trim();
        _bannerInfo =
            'Código "$codigoBarras" no registrado aún. Completa los datos para crearlo con su primera entrada.';
      } else {
        _bannerInfo = null;
      }
    });
  }

  void _volverASeleccion() {
    setState(() {
      _modo = _ModoEntrada.seleccionar;
      _materialSeleccionado = null;
      _errorMessage = null;
      _bannerInfo = null;
    });
  }

  Future<void> _guardarEntrada() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fechaCaducidad != null &&
        _fechaAlerta != null &&
        _fechaAlerta!.isAfter(_fechaCaducidad!)) {
      setState(
          () => _errorMessage = 'La fecha de alerta no puede ser posterior a la fecha de caducidad');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventarioRepositoryProvider);
      final fmt = DateFormat('yyyy-MM-dd');
      final cantidad = int.parse(_cantidadController.text.trim());
      final costo = _costoController.text.trim().isNotEmpty
          ? double.tryParse(_costoController.text.trim())
          : null;
      final codigoLote = _loteCodigoController.text.trim().isNotEmpty
          ? _loteCodigoController.text.trim()
          : 'Lote General';
      final caducidadStr = _fechaCaducidad != null ? fmt.format(_fechaCaducidad!) : null;
      final alertaStr = _fechaAlerta != null ? fmt.format(_fechaAlerta!) : null;

      String nombreConfirmacion;

      if (_modo == _ModoEntrada.loteExistente) {
        if (_materialSeleccionado == null) {
          setState(() => _errorMessage = 'Selecciona un material');
          return;
        }
        await repo.registrarEntrada(
          materialId: _materialSeleccionado!.id,
          cantidad: cantidad,
          fechaCaducidad: caducidadStr,
          fechaAlerta: alertaStr,
          costoUnitario: costo,
          numeroLote: codigoLote,
        );
        nombreConfirmacion = _materialSeleccionado!.nombre;
      } else {
        if (_areaNueva == null || _categoriaNueva == null) {
          setState(() => _errorMessage = 'Selecciona un área y una categoría para el nuevo material');
          return;
        }
        final creado = await repo.crearMaterial(
          nombre: _nombreController.text.trim(),
          codigoBarras: _codigoBarrasController.text.trim(),
          areaId: _areaNueva!.id,
          categoriaId: _categoriaNueva!.id,
          unidadMedida: _unidadController.text.trim().isNotEmpty
              ? _unidadController.text.trim()
              : 'unidad',
          stockMinimo: int.tryParse(_stockMinimoController.text.trim()) ?? 5,
          stockInicial: cantidad,
          codigoLote: codigoLote,
          fechaCaducidad: caducidadStr,
          fechaAlertaVencimiento: alertaStr,
          costoUnitario: costo,
        );
        nombreConfirmacion = creado.nombre;
      }

      ref.invalidate(materialesFiltradosProvider);
      ref.invalidate(materialesAdminProvider);
      ref.invalidate(alertasActivasProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _modo == _ModoEntrada.crearYEntrar
                  ? 'Material "$nombreConfirmacion" creado con $cantidad unidades de entrada.'
                  : 'Entrada de $cantidad unidades de $nombreConfirmacion registrada con éxito.',
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
        setState(() => _errorMessage = e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: CeosColors.statusDanger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: CeosColors.statusDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_modo) {
      _ModoEntrada.seleccionar => 'Registrar Entrada',
      _ModoEntrada.loteExistente => 'Entrada de Material',
      _ModoEntrada.crearYEntrar => 'Nuevo Material + Entrada',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () {
            if (_modo != _ModoEntrada.seleccionar && widget.initialMaterialId == null) {
              _volverASeleccion();
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/inventario');
            }
          },
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_bannerInfo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologiaLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CeosColors.areaOdontologia.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.info,
                          size: 18,
                          color: CeosColors.areaOdontologia,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bannerInfo!,
                            style: CeosTheme.body(
                              fontSize: 13,
                              color: CeosColors.areaOdontologia,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CeosColors.statusDangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CeosColors.statusDanger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_modo == _ModoEntrada.seleccionar) _buildPasoSeleccion(),
                if (_modo == _ModoEntrada.loteExistente) _buildPasoLoteExistente(),
                if (_modo == _ModoEntrada.crearYEntrar) _buildPasoCrearYEntrar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasoSeleccion() {
    final areasAsync = ref.watch(areasProvider);
    final materialesAsync = ref.watch(materialesAdminProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '1. Busca o escanea el material',
          style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Si el material ya existe agregarás un lote; si no existe, podrás crearlo junto con su entrada.',
          style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
        ),
        const SizedBox(height: 14),

        // Barra de búsqueda + botón cámara
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código...',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () => setState(() => _searchController.clear()),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _buscandoCodigo ? null : _escanearEnBuscador,
                icon: _buscandoCodigo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(PhosphorIconsRegular.barcode),
                label: const Text('Escanear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filtro rápido de área
        areasAsync.when(
          data: (areas) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtroAreaId == null,
                  onSelected: (_) => setState(() => _filtroAreaId = null),
                ),
                const SizedBox(width: 8),
                ...areas.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(a.nombre),
                      selected: _filtroAreaId == a.id,
                      onSelected: (_) => setState(() => _filtroAreaId = a.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 14),

        // Botón prominente para crear material nuevo + entrada
        OutlinedButton.icon(
          onPressed: () => _iniciarCreacionMaterial(nombreInicial: _searchController.text),
          icon: const Icon(PhosphorIconsRegular.plusCircle),
          label: Text(
            query.isNotEmpty
                ? 'Crear "${_searchController.text.trim()}" y registrar entrada'
                : 'Registrar material nuevo + entrada',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
        const SizedBox(height: 16),

        // Listado filtrado de materiales existentes
        materialesAsync.when(
          data: (materiales) {
            final filtrados = materiales.where((m) {
              if (_filtroAreaId != null && m.areaId != _filtroAreaId) return false;
              if (query.isEmpty) return true;
              final enNombre = m.nombre.toLowerCase().contains(query);
              final enCodigo = (m.codigoBarras ?? '').toLowerCase().contains(query);
              final enArea = m.areaNombre.toLowerCase().contains(query);
              final enCat = m.categoriaNombre.toLowerCase().contains(query);
              return enNombre || enCodigo || enArea || enCat;
            }).toList();

            if (filtrados.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.package,
                      size: 40,
                      color: CeosColors.lightTextMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No se encontraron materiales con ese criterio.',
                      style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final m = filtrados[idx];
                return InkWell(
                  onTap: () => _seleccionarMaterialExistente(m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: CeosColors.areaOdontologiaLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            IconCatalog.getIcon(m.icono ?? m.categoriaIcono),
                            color: CeosColors.areaOdontologia,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.nombre,
                                style: CeosTheme.heading(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${m.areaNombre} · ${m.categoriaNombre}',
                                style: CeosTheme.body(
                                  fontSize: 12,
                                  color: CeosColors.lightTextSecondary,
                                ),
                              ),
                              if (m.codigoBarras != null && m.codigoBarras!.isNotEmpty)
                                Text(
                                  'Cód: ${m.codigoBarras}',
                                  style: CeosTheme.dataMono(
                                    fontSize: 11,
                                    color: CeosColors.lightTextMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${m.stockTotal} ${m.unidadMedida}',
                              style: CeosTheme.dataMono(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: m.esCritico
                                    ? CeosColors.statusDanger
                                    : CeosColors.areaOdontologia,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Agregar lote →',
                              style: CeosTheme.body(
                                fontSize: 11,
                                color: CeosColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Error cargando catálogo: $e'),
        ),
      ],
    );
  }

  Widget _buildPasoLoteExistente() {
    final m = _materialSeleccionado!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta resumen del material seleccionado
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CeosColors.areaOdontologiaLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CeosColors.areaOdontologia.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                IconCatalog.getIcon(m.icono ?? m.categoriaIcono),
                size: 32,
                color: CeosColors.areaOdontologia,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.nombre,
                      style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${m.areaNombre} · ${m.categoriaNombre} · Stock: ${m.stockTotal} ${m.unidadMedida}',
                      style: CeosTheme.body(
                        fontSize: 12,
                        color: CeosColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.initialMaterialId == null)
                TextButton(
                  onPressed: _volverASeleccion,
                  child: const Text('Cambiar'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ..._buildCamposLote(unidadMedida: m.unidadMedida),

        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _guardarEntrada,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(PhosphorIconsRegular.check),
          label: const Text('Guardar Entrada'),
        ),
      ],
    );
  }

  Widget _buildPasoCrearYEntrar() {
    final areasAsync = ref.watch(areasProvider);
    final categoriasAsync = ref.watch(categoriasProvider(_areaNueva?.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1. Datos del Nuevo Material',
              style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _volverASeleccion,
              child: const Text('Buscar existente'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre del material *',
            hintText: 'Ej. Guantes de nitrilo talla M',
            prefixIcon: Icon(PhosphorIconsRegular.package),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del material' : null,
        ),
        const SizedBox(height: 12),

        // Código de barras opcional con escáner integrado
        TextFormField(
          controller: _codigoBarrasController,
          decoration: InputDecoration(
            labelText: 'Código de barras (opcional)',
            hintText: 'Escanea o escribe el código del empaque',
            prefixIcon: const Icon(PhosphorIconsRegular.barcode),
            suffixIcon: IconButton(
              icon: const Icon(PhosphorIconsRegular.camera),
              tooltip: 'Escanear código de barras',
              onPressed: _escanearParaCampoNuevo,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Área
        areasAsync.when(
          data: (areas) => DropdownButtonFormField<AreaModel>(
            value: areas.any((a) => a.id == _areaNueva?.id)
                ? areas.firstWhere((a) => a.id == _areaNueva?.id)
                : (areas.isNotEmpty ? areas.first : null),
            decoration: const InputDecoration(
              labelText: 'Área clínica *',
              prefixIcon: Icon(PhosphorIconsRegular.buildings),
            ),
            items: areas
                .map((a) => DropdownMenuItem(value: a, child: Text(a.nombre)))
                .toList(),
            onChanged: (a) {
              setState(() {
                _areaNueva = a;
                _categoriaNueva = null;
              });
            },
            validator: (v) => v == null ? 'Selecciona un área' : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error cargando áreas: $e'),
        ),
        const SizedBox(height: 12),

        // Categoría filtrada por área
        categoriasAsync.when(
          data: (categorias) {
            final seleccionValida =
                categorias.any((c) => c.id == _categoriaNueva?.id)
                    ? categorias.firstWhere((c) => c.id == _categoriaNueva?.id)
                    : null;
            return DropdownButtonFormField<CategoriaModel>(
              value: seleccionValida,
              decoration: const InputDecoration(
                labelText: 'Categoría *',
                prefixIcon: Icon(PhosphorIconsRegular.tag),
              ),
              items: categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.nombre)))
                  .toList(),
              onChanged: (c) => setState(() => _categoriaNueva = c),
              validator: (v) => v == null ? 'Selecciona una categoría' : null,
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error cargando categorías: $e'),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _unidadController,
                decoration: const InputDecoration(
                  labelText: 'Unidad de medida *',
                  hintText: 'caja, unidad, ml...',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _stockMinimoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock mínimo',
                  hintText: '5',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          '2. Datos del Primer Lote (Entrada)',
          style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        ..._buildCamposLote(
          unidadMedida: _unidadController.text.trim().isNotEmpty
              ? _unidadController.text.trim()
              : 'unidades',
        ),

        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _guardarEntrada,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(PhosphorIconsRegular.checkCircle),
          label: const Text('Crear Material y Registrar Entrada'),
        ),
      ],
    );
  }

  List<Widget> _buildCamposLote({required String unidadMedida}) {
    final fmt = DateFormat('dd/MM/yyyy');

    return [
      TextFormField(
        controller: _cantidadController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Cantidad que ingresa *',
          hintText: 'Ej. 20',
          suffixText: unidadMedida,
          prefixIcon: const Icon(PhosphorIconsRegular.plusMinus),
        ),
        validator: (v) {
          final n = int.tryParse((v ?? '').trim());
          if (n == null || n <= 0) return 'Ingresa una cantidad válida mayor a 0';
          return null;
        },
      ),
      const SizedBox(height: 12),

      // Fecha de caducidad
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _fechaCaducidad ?? DateTime.now().add(const Duration(days: 180)),
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
          );
          if (picked != null) _onFechaCaducidadSeleccionada(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Fecha de caducidad (opcional)',
            prefixIcon: const Icon(PhosphorIconsRegular.calendar),
            suffixIcon: _fechaCaducidad != null
                ? IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, size: 18),
                    onPressed: () => setState(() {
                      _fechaCaducidad = null;
                      _fechaAlerta = null;
                    }),
                  )
                : null,
          ),
          child: Text(
            _fechaCaducidad != null ? fmt.format(_fechaCaducidad!) : 'Sin fecha de caducidad',
            style: CeosTheme.body(
              color: _fechaCaducidad != null
                  ? CeosColors.lightTextPrimary
                  : CeosColors.lightTextMuted,
            ),
          ),
        ),
      ),
      if (_fechaCaducidad != null) ...[
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _fechaAlerta ?? _fechaCaducidad!,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: _fechaCaducidad!,
            );
            if (picked != null) setState(() => _fechaAlerta = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de alerta preventiva',
              prefixIcon: Icon(PhosphorIconsRegular.bell),
            ),
            child: Text(
              _fechaAlerta != null ? fmt.format(_fechaAlerta!) : 'Sin alerta',
              style: CeosTheme.body(),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),

      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _loteCodigoController,
              decoration: const InputDecoration(
                labelText: 'Código de lote (opc.)',
                hintText: 'Lote General',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _costoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Costo unit. (opc.)',
                hintText: '0.00',
                prefixText: 'Bs ',
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
