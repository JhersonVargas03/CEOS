import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/storage_provider.dart';

class EditarRolScreen extends ConsumerStatefulWidget {
  final int? rolId; // null if creating a new role

  const EditarRolScreen({super.key, this.rolId});

  @override
  ConsumerState<EditarRolScreen> createState() => _EditarRolScreenState();
}

class _EditarRolScreenState extends ConsumerState<EditarRolScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();

  List<PermisoModel> _todosLosPermisos = [];
  final List<String> _permisosSeleccionadosCodigos = [];
  bool _isSuperadminRole = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final permisos = await repo.obtenerPermisos();

      if (widget.rolId != null) {
        final roles = await repo.obtenerRoles();
        final match = roles.firstWhere((r) => r.id == widget.rolId);

        _nombreController.text = match.nombre;
        _descripcionController.text = match.descripcion;
        _permisosSeleccionadosCodigos.addAll(match.permisosCodigos);
        _isSuperadminRole = match.esSuperadmin || match.nombre.toLowerCase() == 'superadmin';
      }

      setState(() {
        _todosLosPermisos = permisos;
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
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardarRol() async {
    if (_nombreController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Ingresa el nombre del rol');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      if (widget.rolId == null) {
        await repo.crearRol(
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          permisosCodigos: _permisosSeleccionadosCodigos,
        );
      } else {
        await repo.actualizarRol(
          rolId: widget.rolId!,
          nombre: _nombreController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          permisosCodigos: _permisosSeleccionadosCodigos,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rol guardado exitosamente.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
        context.pop();
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

  Future<void> _confirmarEliminarRol() async {
    if (widget.rolId == null || _isSuperadminRole) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Rol?'),
        content: Text(
          'El rol "${_nombreController.text}" será eliminado permanentemente.',
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
        final repo = ref.read(adminRepositoryProvider);
        await repo.eliminarRol(widget.rolId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rol eliminado correctamente.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
          context.pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error al eliminar: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rol')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Group permissions by module
    final grupos = <String, List<PermisoModel>>{};
    for (final p in _todosLosPermisos) {
      grupos.putIfAbsent(p.modulo, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: Text(widget.rolId == null ? 'Crear Nuevo Rol' : 'Editar Rol'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bloqueo explícito en UI para rol Superadmin (HU-425)
              if (_isSuperadminRole) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CeosColors.roleSuperadmin.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CeosColors.roleSuperadmin.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(PhosphorIconsFill.crown, color: CeosColors.roleSuperadmin, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'El rol Superadmin cuenta con privilegios totales inmutables y no puede ser modificado.',
                          style: CeosTheme.body(
                            fontSize: 12,
                            color: CeosColors.roleSuperadmin,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CeosColors.statusDangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!, style: CeosTheme.body(color: CeosColors.statusDanger)),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _nombreController,
                enabled: !_isSuperadminRole,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Rol *',
                  prefixIcon: Icon(PhosphorIconsRegular.shieldCheck),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _descripcionController,
                enabled: !_isSuperadminRole,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción del rol',
                  prefixIcon: Icon(PhosphorIconsRegular.notePencil),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Permisos del Rol (Agrupados por Módulo)',
                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Permisos agrupados en ExpansionTiles (HU-425)
              ...grupos.entries.map((entry) {
                final modulo = entry.key;
                final permisosModulo = entry.value;
                final seleccionadosEnModulo = permisosModulo
                    .where((p) => _permisosSeleccionadosCodigos.contains(p.codigo))
                    .length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(modulo, style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '$seleccionadosEnModulo de ${permisosModulo.length} permisos asignados',
                      style: CeosTheme.body(fontSize: 11, color: CeosColors.lightTextMuted),
                    ),
                    children: permisosModulo.map((p) {
                      final isChecked = _isSuperadminRole || _permisosSeleccionadosCodigos.contains(p.codigo);

                      return CheckboxListTile(
                        title: Text(p.nombre, style: CeosTheme.body(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(p.descripcion, style: CeosTheme.body(fontSize: 11)),
                        value: isChecked,
                        onChanged: _isSuperadminRole
                            ? null
                            : (val) {
                                setState(() {
                                  if (val == true) {
                                    _permisosSeleccionadosCodigos.add(p.codigo);
                                  } else {
                                    _permisosSeleccionadosCodigos.remove(p.codigo);
                                  }
                                });
                              },
                      );
                    }).toList(),
                  ),
                );
              }),

              const SizedBox(height: 24),

              if (!_isSuperadminRole)
                ElevatedButton(
                  onPressed: _isLoading ? null : _guardarRol,
                  child: const Text('Guardar Rol y Permisos'),
                ),

              // Eliminar Rol (solo roles personalizados no-superadmin y editando uno existente)
              if (!_isSuperadminRole && widget.rolId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CeosColors.statusDanger,
                    side: const BorderSide(color: CeosColors.statusDanger),
                  ),
                  icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                  label: const Text('Eliminar Rol'),
                  onPressed: _isLoading ? null : _confirmarEliminarRol,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
