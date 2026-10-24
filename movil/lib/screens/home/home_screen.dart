import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/item_navegacion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/notificaciones_provider.dart';
import '../../providers/permisos_provider.dart';
import '../../widgets/chip_rol_activo.dart';
import '../../widgets/icono_notificaciones.dart';
import '../../widgets/item_actividad_reciente.dart';
import '../../widgets/selector_area.dart';
import '../../widgets/skeleton_home.dart';
import '../../widgets/tarjeta_alerta.dart';

// ── Modelo interno para grupo de acciones rápidas ──────────────────────────
class _GrupoAcciones {
  final String titulo;
  final IconData icono;
  final Color color;
  final List<ItemNavegacion> items;
  const _GrupoAcciones({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.items,
  });
}

// ── Widget de sección con scroll horizontal ─────────────────────────────────
class _SeccionAcciones extends StatelessWidget {
  final _GrupoAcciones grupo;
  const _SeccionAcciones({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del grupo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: grupo.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(grupo.icono, size: 14, color: grupo.color),
              ),
              const SizedBox(width: 8),
              Text(
                grupo.titulo,
                style: CeosTheme.heading(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: grupo.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila de tarjetas con scroll horizontal (íconos amplios y responsivos)
          SizedBox(
            height: 98,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: grupo.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = grupo.items[index];
                return InkWell(
                  onTap: () => context.push(item.route),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 124,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? CeosColors.darkCard.withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? grupo.color.withValues(alpha: 0.28)
                            : grupo.color.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: grupo.color.withValues(alpha: isDark ? 0.1 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: grupo.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(item.icon, size: 22, color: grupo.color),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              item.label,
                              style: CeosTheme.heading(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pantalla principal ──────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);
    final alertasAsync = ref.watch(alertasActivasProvider);
    final historialAsync = ref.watch(historialRecienteProvider);

    return permisosAsync.when(
      data: (permisos) {
        // ── Catálogo de acciones por grupo ────────────────────────────────
        final gruposDefinidos = [
          _GrupoAcciones(
            titulo: 'Inventario',
            icono: PhosphorIconsRegular.package,
            color: CeosColors.areaOdontologia,
            items: [
              const ItemNavegacion(
                label: 'Ver Inventario',
                icon: PhosphorIconsRegular.package,
                route: '/inventario',
              ),
              const ItemNavegacion(
                label: 'Nueva Entrada',
                icon: PhosphorIconsRegular.arrowSquareIn,
                route: '/inventario/entrada',
                permisoRequerido: 'registrar_entrada',
              ),
              const ItemNavegacion(
                label: 'Registrar Salida',
                icon: PhosphorIconsRegular.arrowSquareOut,
                route: '/inventario/salida',
                permisoRequerido: 'registrar_salida',
              ),
              const ItemNavegacion(
                label: 'Hacer Ajuste',
                icon: PhosphorIconsRegular.slidersHorizontal,
                route: '/inventario/ajuste',
                permisoRequerido: 'ajustar_inventario',
              ),
              const ItemNavegacion(
                label: 'Gestión Catálogo',
                icon: PhosphorIconsRegular.stack,
                route: '/inventario/gestion',
                permisoRequerido: 'gestionar_catalogo_inventario',
              ),
            ],
          ),
          _GrupoAcciones(
            titulo: 'Análisis',
            icono: PhosphorIconsRegular.chartBar,
            color: CeosColors.roleSuperadmin,
            items: [
              const ItemNavegacion(
                label: 'Dashboard',
                icon: PhosphorIconsRegular.chartBar,
                route: '/inventario/dashboard',
                permisoRequerido: 'ver_dashboard',
              ),
            ],
          ),
          _GrupoAcciones(
            titulo: 'Solicitudes',
            icono: PhosphorIconsRegular.tray,
            color: CeosColors.statusSuccess,
            items: [
              const ItemNavegacion(
                label: 'Solicitar Material',
                icon: PhosphorIconsRegular.plusCircle,
                route: '/inventario/solicitar',
                permisoRequerido: 'solicitar_material',
              ),
              const ItemNavegacion(
                label: 'Mis Solicitudes',
                icon: PhosphorIconsRegular.tray,
                route: '/inventario/mis-solicitudes',
                permisoRequerido: 'solicitar_material',
              ),
              const ItemNavegacion(
                label: 'Resolver Solicitudes',
                icon: PhosphorIconsRegular.checkSquareOffset,
                route: '/inventario/resolver-solicitudes',
                permisoRequerido: 'aprobar_solicitud',
              ),
            ],
          ),
        ];

        // Filtrar ítems visibles por permisos y eliminar grupos vacíos
        final gruposVisibles = gruposDefinidos
            .map((g) => _GrupoAcciones(
                  titulo: g.titulo,
                  icono: g.icono,
                  color: g.color,
                  items: g.items
                      .where((item) => item.puedeMostrar(
                            permisosUsuario: permisos,
                            esSuperadmin: esSuperadmin,
                          ))
                      .toList(),
                ))
            .where((g) => g.items.isNotEmpty)
            .toList();

        final puedeVerAlertas = esSuperadmin ||
            permisos.contains('ver_alertas_inventario') ||
            permisos.contains('ver_inventario');
        final tieneAccesoAdmin = esSuperadmin ||
            user?.roles.any((r) => r.toLowerCase().contains('admin')) == true ||
            permisos.contains('gestionar_usuarios') ||
            permisos.contains('gestionar_roles') ||
            permisos.contains('configurar_sistema') ||
            permisos.contains('gestionar_catalogo_inventario');

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(alertasActivasProvider);
                ref.invalidate(historialRecienteProvider);
                ref.invalidate(areasProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con usuario, rol y notificaciones (HU-407)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => context.push('/perfil'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, ${user?.nombreMostrado ?? "Personal"}',
                                  style: CeosTheme.heading(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (user != null)
                                  ChipRolActivo(
                                    rol: user.rolPrincipal,
                                    esSuperadmin: user.esSuperadmin,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconoNotificaciones(
                              onTap: () => context.push('/notificaciones'),
                            ),
                            IconButton(
                              icon: const Icon(PhosphorIconsRegular.userCircle, size: 24),
                              tooltip: 'Mi Perfil',
                              onPressed: () => context.push('/perfil'),
                            ),
                            if (tieneAccesoAdmin)
                              IconButton(
                                icon: const Icon(PhosphorIconsRegular.gear, size: 24),
                                tooltip: 'Administración',
                                onPressed: () => context.push('/administracion'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Selector de Área (HU-411)
                    const SelectorArea(navegarAlSeleccionar: true),
                    const SizedBox(height: 24),

                    // ── Acciones Rápidas agrupadas (HU-407) ───────────────
                    Text(
                      'Acciones Rápidas',
                      style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (gruposVisibles.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No tienes acciones directas asignadas.',
                            style: CeosTheme.body(color: CeosColors.lightTextMuted),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: gruposVisibles.map((grupo) {
                          return _SeccionAcciones(grupo: grupo);
                        }).toList(),
                      ),
                    const SizedBox(height: 8),

                    // Resumen de Alertas Activas (HU-408)
                    if (puedeVerAlertas) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Alertas de Inventario',
                            style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => context.push('/inventario'),
                            child: Text(
                              'Ver todo',
                              style: CeosTheme.body(
                                fontSize: 13,
                                color: CeosColors.areaOdontologia,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      alertasAsync.when(
                        data: (alertas) {
                          if (alertas.isEmpty) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? CeosColors.statusSuccess.withValues(alpha: 0.12)
                                    : CeosColors.statusSuccessLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: CeosColors.statusSuccess.withValues(alpha: isDark ? 0.4 : 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsFill.checkCircle,
                                    color: CeosColors.statusSuccess,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Todo el inventario está en orden. No hay alertas críticas.',
                                      style: CeosTheme.body(
                                        fontSize: 13,
                                        color: CeosColors.statusSuccess,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: alertas.take(3).map((alerta) {
                              return TarjetaAlerta(
                                alerta: alerta,
                                onTap: () {
                                  if (alerta.materialId != null) {
                                    context.push('/inventario/material/${alerta.materialId}');
                                  } else {
                                    context.push('/inventario');
                                  }
                                },
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Text(
                          'Error al cargar alertas: $e',
                          style: CeosTheme.body(color: CeosColors.statusDanger),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Actividad Reciente (HU-409)
                    Text(
                      'Mi Actividad Reciente',
                      style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    historialAsync.when(
                      data: (movimientos) {
                        if (movimientos.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Aún no registras movimientos recientes en el sistema.',
                                style: CeosTheme.body(
                                  fontSize: 13,
                                  color: CeosColors.lightTextMuted,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: movimientos.take(4).map((mov) {
                            return ItemActividadReciente(movimiento: mov);
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Text(
                        'Error al cargar actividad: $e',
                        style: CeosTheme.body(color: CeosColors.statusDanger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: SafeArea(child: SkeletonHome())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error al cargar permisos: $e')),
      ),
    );
  }
}
