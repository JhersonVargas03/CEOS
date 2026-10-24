import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/badge_estado.dart';
import '../../widgets/ceos_shimmer.dart';

class MisSolicitudesScreen extends ConsumerWidget {
  const MisSolicitudesScreen({super.key});

  Future<void> _cancelarSolicitud(BuildContext context, WidgetRef ref, SolicitudModel solicitud) async {
    if (!solicitud.esPendiente) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Solicitud?'),
        content: Text('¿Seguro que deseas cancelar la solicitud de ${solicitud.cantidad} unidades de ${solicitud.materialNombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CeosColors.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final repo = ref.read(inventarioRepositoryProvider);
        await repo.cancelarSolicitud(solicitud.id);
        ref.invalidate(misSolicitudesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud cancelada.'),
              backgroundColor: CeosColors.statusSuccess,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar: $e'),
              backgroundColor: CeosColors.statusDanger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(misSolicitudesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Inicio',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Mis Solicitudes'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plusCircle, size: 24),
            onPressed: () => context.push('/inventario/solicitar'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(misSolicitudesProvider),
          child: solicitudesAsync.when(
            data: (solicitudes) {
              if (solicitudes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.tray,
                          size: 48,
                          color: CeosColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No has realizado solicitudes de reposición.',
                          style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(PhosphorIconsRegular.plusCircle),
                          label: const Text('Crear Primera Solicitud'),
                          onPressed: () => context.push('/inventario/solicitar'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: solicitudes.length,
                itemBuilder: (context, index) {
                  final sol = solicitudes[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sol.materialNombre,
                                  style: CeosTheme.heading(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              BadgeEstado(estado: sol.estado),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cantidad: ${sol.cantidad} unidades • Motivo: ${sol.motivo}',
                            style: CeosTheme.body(
                              fontSize: 13,
                              color: CeosColors.lightTextSecondary,
                            ),
                          ),
                          if (sol.comentario != null && sol.comentario!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Nota: "${sol.comentario}"',
                              style: CeosTheme.body(
                                fontSize: 12,
                                color: CeosColors.lightTextMuted,
                              ),
                            ),
                          ],
                          if (sol.comentarioResolucion != null && sol.comentarioResolucion!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CeosColors.statusDangerLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Respuesta de inventario: ${sol.comentarioResolucion}',
                                style: CeosTheme.body(
                                  fontSize: 12,
                                  color: CeosColors.statusDanger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          // Acciones de Editar y Cancelar solo para solicitudes pendientes (HU-418)
                          if (sol.esPendiente) ...[
                            const Divider(height: 20),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                                  label: const Text('Editar'),
                                  onPressed: () async {
                                    await context.push('/inventario/editar-solicitud/${sol.id}');
                                    ref.invalidate(misSolicitudesProvider);
                                  },
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(foregroundColor: CeosColors.statusDanger),
                                  icon: const Icon(PhosphorIconsRegular.xCircle, size: 16),
                                  label: const Text('Cancelar'),
                                  onPressed: () => _cancelarSolicitud(context, ref, sol),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const SkeletonListaMateriales(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }
}
