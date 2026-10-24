import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../providers/storage_provider.dart';

class ListaRolesScreen extends ConsumerStatefulWidget {
  const ListaRolesScreen({super.key});

  @override
  ConsumerState<ListaRolesScreen> createState() => _ListaRolesScreenState();
}

class _ListaRolesScreenState extends ConsumerState<ListaRolesScreen> {
  List<RolModel> _roles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarRoles();
  }

  Future<void> _cargarRoles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final list = await repo.obtenerRoles();
      setState(() {
        _roles = list;
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Roles y Permisos'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plusCircle, size: 24),
            onPressed: () async {
              await context.push('/admin/roles/crear');
              _cargarRoles();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('Error: $_errorMessage'))
                : RefreshIndicator(
                    onRefresh: _cargarRoles,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        final r = _roles[index];
                        final isSuperadmin = r.esSuperadmin || r.nombre.toLowerCase() == 'superadmin';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSuperadmin
                                    ? CeosColors.roleSuperadmin.withOpacity(0.12)
                                    : CeosColors.areaOdontologia.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isSuperadmin ? PhosphorIconsFill.crown : PhosphorIconsRegular.shieldCheck,
                                color: isSuperadmin ? CeosColors.roleSuperadmin : CeosColors.areaOdontologia,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.nombre,
                                    style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: r.esDeFabrica
                                        ? CeosColors.areaOdontologiaLight
                                        : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r.esDeFabrica ? 'DE FÁBRICA' : 'PERSONALIZADO',
                                    style: CeosTheme.dataMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: r.esDeFabrica ? CeosColors.areaOdontologia : CeosColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              r.descripcion.isNotEmpty ? r.descripcion : 'Sin descripción',
                              style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón eliminar solo para roles personalizados no-superadmin
                                if (!r.esDeFabrica && !isSuperadmin)
                                  IconButton(
                                    icon: const Icon(PhosphorIconsRegular.trash, color: CeosColors.statusDanger, size: 18),
                                    tooltip: 'Eliminar Rol',
                                    onPressed: () => _confirmarEliminarRol(context, r),
                                  ),
                                const Icon(PhosphorIconsRegular.caretRight, size: 16),
                              ],
                            ),
                            onTap: () async {
                              await context.push('/admin/roles/editar/${r.id}');
                              _cargarRoles();
                            },
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Future<void> _confirmarEliminarRol(BuildContext context, RolModel rol) async {
    if (rol.esDeFabrica || rol.esSuperadmin || rol.nombre.toLowerCase() == 'superadmin') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Rol?'),
        content: Text(
          'El rol "${rol.nombre}" será eliminado permanentemente. Los usuarios que lo tengan asignado perderán sus permisos asociados.',
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
      try {
        final repo = ref.read(adminRepositoryProvider);
        await repo.eliminarRol(rol.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rol "${rol.nombre}" eliminado correctamente.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
        }
        await _cargarRoles();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar el rol: $e'),
              backgroundColor: CeosColors.statusDanger,
            ),
          );
        }
      }
    }
  }
}
