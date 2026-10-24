import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/storage_provider.dart';

class AuditoriaScreen extends ConsumerStatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  ConsumerState<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends ConsumerState<AuditoriaScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _registros = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  int _total = 0;
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  String _filtroAccion = 'Todas';
  final List<String> _categoriasFiltro = [
    'Todas',
    'Accesos',
    'Inventario',
    'Ingreso Lote',
    'Salida FEFO',
    'Ajustes',
    'Usuarios y Roles',
    'Respaldos',
    'Reportes',
  ];

  @override
  void initState() {
    super.initState();
    _cargarAuditoria();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      final totalPages = (_total / _pageSize).ceil();
      if (!_isLoadingMore && _page < totalPages) {
        _cargarMas();
      }
    }
  }

  String? _getAccionParam(String categoria) {
    switch (categoria) {
      case 'Accesos':
        return 'ACCESOS';
      case 'Inventario':
        return 'INVENTARIO';
      case 'Ingreso Lote':
        return 'INGRESO_LOTE';
      case 'Salida FEFO':
        return 'REGISTRO_SALIDA_FEFO';
      case 'Ajustes':
        return 'AJUSTE_INVENTARIO';
      case 'Usuarios y Roles':
        return 'USUARIOS_ROLES';
      case 'Respaldos':
        return 'RESPALDOS';
      case 'Reportes':
        return 'REPORTES';
      default:
        return null;
    }
  }

  Future<void> _cargarAuditoria({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _registros = [];
      });
    }

    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.obtenerAuditoria(
        page: _page,
        pageSize: _pageSize,
        accion: _getAccionParam(_filtroAccion),
        search: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
      );

      final newItems = (result['results'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      setState(() {
        if (reset) {
          _registros = newItems;
        } else {
          _registros.addAll(newItems);
        }
        _total = result['total'] as int? ?? 0;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_isLoading || _isLoadingMore) return;
    if (_registros.length >= _total) return;

    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    await _cargarAuditoria(reset: false);
  }

  Color _colorAccion(String accion) {
    final a = accion.toLowerCase();
    if (a.contains('login') || a.contains('acceso')) return CeosColors.statusSuccess;
    if (a.contains('error') || a.contains('fail') || a.contains('denegado')) {
      return CeosColors.statusDanger;
    }
    if (a.contains('eliminar') || a.contains('delete')) return CeosColors.statusDanger;
    if (a.contains('crear') || a.contains('registro')) return CeosColors.areaOdontologia;
    if (a.contains('actualizar') || a.contains('editar')) return CeosColors.statusWarning;
    return CeosColors.lightTextSecondary;
  }

  IconData _iconAccion(String accion) {
    final a = accion.toLowerCase();
    if (a.contains('login') || a.contains('acceso')) return PhosphorIconsRegular.signIn;
    if (a.contains('logout') || a.contains('cierre')) return PhosphorIconsRegular.signOut;
    if (a.contains('eliminar') || a.contains('delete')) return PhosphorIconsRegular.trash;
    if (a.contains('crear') || a.contains('registro')) return PhosphorIconsRegular.plusCircle;
    if (a.contains('actualizar') || a.contains('editar')) return PhosphorIconsRegular.pencilSimple;
    if (a.contains('error') || a.contains('fail')) return PhosphorIconsRegular.warning;
    return PhosphorIconsRegular.clockCounterClockwise;
  }

  String _formatFecha(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final pad = (int n) => n.toString().padLeft(2, '0');
      return '${pad(dt.day)}/${pad(dt.month)}/${dt.year} ${pad(dt.hour)}:${pad(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }

  /// Convierte cualquier valor a String? de forma segura.
  /// Retorna null si el valor es null, string directo si ya es String,
  /// o toString() si es otro tipo (e.g. Map, num).
  String? _safeStr(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  String _formatearDetalles(dynamic rawDetalles) {
    if (rawDetalles == null) return '';
    if (rawDetalles is String) return rawDetalles;
    if (rawDetalles is Map) {
      if (rawDetalles.isEmpty) return '';
      return rawDetalles.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' • ');
    }
    return rawDetalles.toString();
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
        title: const Text('Auditoría del Sistema'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            tooltip: 'Actualizar',
            onPressed: () => _cargarAuditoria(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por acción, usuario o detalles…',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _cargarAuditoria();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (_) => _cargarAuditoria(),
                onChanged: (val) {
                  if (val.isEmpty) _cargarAuditoria();
                },
              ),
            ),

            // Chips de Categorías de Auditoría
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categoriasFiltro.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = _categoriasFiltro[idx];
                  final isSelected = _filtroAccion == cat;
                  return FilterChip(
                    label: Text(
                      cat,
                      style: CeosTheme.body(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : CeosColors.lightTextSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: CeosColors.areaOdontologia,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _filtroAccion = cat;
                        });
                        _cargarAuditoria();
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // Contador de resultados
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '$_total registros encontrados',
                      style: CeosTheme.body(
                        fontSize: 12,
                        color: CeosColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Lista
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                PhosphorIconsRegular.warning,
                                size: 40,
                                color: CeosColors.statusDanger,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Error al cargar auditoría',
                                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _errorMessage!,
                                style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _cargarAuditoria,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _registros.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.clipboardText,
                                    size: 48,
                                    color: CeosColors.lightTextMuted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No hay registros de auditoría',
                                    style: CeosTheme.heading(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _cargarAuditoria,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                itemCount: _registros.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _registros.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }

                                  final r = _registros[index];
                                  // Safe cast: some fields may arrive as Map if backend evolves
                                  final accion = _safeStr(r['accion']) ?? '—';
                                  final usuario = _safeStr(r['usuario']) ?? 'Sistema';
                                  final detalles = _formatearDetalles(r['detalles']);
                                  final fecha = _formatFecha(_safeStr(r['fecha_hora']));
                                  final ip = _safeStr(r['ip_address']) ?? '';
                                  final color = _colorAccion(accion);
                                  final icon = _iconAccion(accion);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(icon, color: color, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        accion,
                                                        style: CeosTheme.body(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: color,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      fecha,
                                                      style: CeosTheme.dataMono(
                                                        fontSize: 10,
                                                        color: CeosColors.lightTextMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Usuario: $usuario${ip.isNotEmpty ? ' • IP: $ip' : ''}',
                                                  style: CeosTheme.body(
                                                    fontSize: 11,
                                                    color: CeosColors.lightTextSecondary,
                                                  ),
                                                ),
                                                if (detalles.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    detalles,
                                                    style: CeosTheme.body(
                                                      fontSize: 11,
                                                      color: CeosColors.lightTextMuted,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
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
