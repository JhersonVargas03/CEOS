import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/admin_models.dart';
import '../../models/inventario_models.dart';
import '../../models/usuario_model.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/item_actividad_reciente.dart';

class DetalleUsuarioScreen extends ConsumerStatefulWidget {
  final int userId;

  const DetalleUsuarioScreen({super.key, required this.userId});

  @override
  ConsumerState<DetalleUsuarioScreen> createState() => _DetalleUsuarioScreenState();
}

class _DetalleUsuarioScreenState extends ConsumerState<DetalleUsuarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UsuarioModel? _usuario;
  List<RolModel> _rolesDisponibles = [];
  List<int> _rolesSeleccionadosIds = [];
  List<MovimientoHistorialModel> _historial = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDetalle();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final user = await repo.obtenerDetalleUsuario(widget.userId);
      final roles = await repo.obtenerRoles();
      final hist = await ref.read(notificacionesRepositoryProvider).obtenerHistorialUsuario(widget.userId);

      final selected = <int>[];
      for (final r in roles) {
        if (user.roles.any((ur) => ur.toLowerCase() == r.nombre.toLowerCase())) {
          selected.add(r.id);
        }
      }

      setState(() {
        _usuario = user;
        _rolesDisponibles = roles;
        _rolesSeleccionadosIds = selected;
        _historial = hist;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarRoles() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.actualizarRolesUsuario(widget.userId, _rolesSeleccionadosIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Roles del usuario actualizados.'),
            backgroundColor: CeosColors.statusSuccess,
          ),
        );
      }
      _cargarDetalle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: CeosColors.statusDanger),
        );
      }
    }
  }

  Future<void> _cambiarEstadoActivo() async {
    if (_usuario == null) return;
    final nuevoEstado = !_usuario!.activo;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nuevoEstado ? '¿Reactivar Cuenta?' : '¿Desactivar Cuenta?'),
        content: Text(
          nuevoEstado
              ? 'El usuario volverá a tener acceso a sus funciones habituales según sus roles.'
              : 'El usuario quedará en modo de solo lectura (podrá ver únicamente su historial y reportes pasados).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado ? CeosColors.statusSuccess : CeosColors.statusDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(nuevoEstado ? 'Reactivar' : 'Desactivar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final repo = ref.read(adminRepositoryProvider);
        await repo.actualizarEstadoUsuario(widget.userId, nuevoEstado);
        _cargarDetalle();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _cerrarSesionRemota() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar Sesión Remota?'),
        content: const Text(
          'Se incrementará la versión de sesión del usuario, invalidando todos los tokens activos en cualquier dispositivo de forma inmediata.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión Remota'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final repo = ref.read(adminRepositoryProvider);
        await repo.cerrarSesionRemota(widget.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesión cerrada en todos los dispositivos del usuario.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Usuario')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _usuario == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowLeft),
            tooltip: 'Atrás',
            onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
          ),
          title: const Text('Detalle de Usuario'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: CeosColors.statusDanger),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No se pudo cargar la información del usuario.',
                  textAlign: TextAlign.center,
                  style: CeosTheme.body(color: CeosColors.statusDanger),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _cargarDetalle,
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final u = _usuario!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin'),
        ),
        title: Text(u.username),
        bottom: TabBar(
          controller: _tabController,
          labelColor: CeosColors.areaOdontologia,
          indicatorColor: CeosColors.areaOdontologia,
          tabs: const [
            Tab(text: 'Roles y Acciones'),
            Tab(text: 'Historial / Auditoría'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Roles y Acciones
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Usuario: ${u.username}', style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Correo: ${u.correoInterno}', style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary)),
                        Text('Teléfono: ${u.telefono.isNotEmpty ? u.telefono : "No registrado"}', style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              u.activo ? 'ESTADO: ACTIVO' : 'ESTADO: INACTIVO',
                              style: CeosTheme.dataMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: u.activo ? CeosColors.statusSuccess : CeosColors.statusDanger,
                              ),
                            ),
                            const Spacer(),
                            Text('Versión Sesión: v${u.sessionVersion}', style: CeosTheme.dataMono(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Asignación de Roles (Multi-Rol)', style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  ..._rolesDisponibles.map((r) {
                    final isChecked = _rolesSeleccionadosIds.contains(r.id);

                    return CheckboxListTile(
                      title: Text(r.nombre, style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(r.descripcion.isNotEmpty ? r.descripcion : 'Rol del sistema', style: CeosTheme.body(fontSize: 12)),
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _rolesSeleccionadosIds.add(r.id);
                          } else {
                            _rolesSeleccionadosIds.remove(r.id);
                          }
                        });
                      },
                    );
                  }),

                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _guardarRoles,
                    child: const Text('Actualizar Roles'),
                  ),
                  const Divider(height: 36),

                  Text('Acciones de Cuenta', style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: u.activo ? CeosColors.statusWarning : CeosColors.statusSuccess,
                    ),
                    icon: Icon(u.activo ? PhosphorIconsRegular.userMinus : PhosphorIconsRegular.userCheck),
                    label: Text(u.activo ? 'Desactivar Usuario' : 'Reactivar Usuario'),
                    onPressed: _cambiarEstadoActivo,
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CeosColors.statusDanger,
                      side: const BorderSide(color: CeosColors.statusDanger),
                    ),
                    icon: const Icon(PhosphorIconsRegular.signOut),
                    label: const Text('Cerrar Sesión Remota en Todos los Dispositivos'),
                    onPressed: _cerrarSesionRemota,
                  ),
                ],
              ),
            ),

            // Tab 2: Historial / Auditoría
            _historial.isEmpty
                ? Center(
                    child: Text('No hay registros de auditoría para este usuario.', style: CeosTheme.body(color: CeosColors.lightTextMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _historial.length,
                    itemBuilder: (context, index) => ItemActividadReciente(movimiento: _historial[index]),
                  ),
          ],
        ),
      ),
    );
  }
}
