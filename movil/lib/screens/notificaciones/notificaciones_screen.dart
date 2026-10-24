import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/notificaciones_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/ceos_shimmer.dart';

import 'package:go_router/go_router.dart';

class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificacionesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Volver',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.checkSquareOffset),
            tooltip: 'Marcar todas como leídas',
            onPressed: () async {
              try {
                await ref.read(notificacionesRepositoryProvider).marcarTodasLeidas();
                ref.invalidate(notificacionesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Todas las notificaciones marcadas como leídas.'),
                      backgroundColor: CeosColors.statusSuccess,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: CeosColors.statusDanger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificacionesProvider),
          child: notifsAsync.when(
            data: (notificaciones) {
              if (notificaciones.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.bellSlash,
                          size: 48,
                          color: CeosColors.lightTextMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes notificaciones pendientes.',
                          style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notificaciones.length,
                itemBuilder: (context, index) {
                  final notif = notificaciones[index];
                  final isUnread = !notif.leida;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: isUnread
                        ? CeosColors.areaOdontologiaLight.withValues(alpha: 0.4)
                        : null,
                    child: ListTile(
                      leading: Icon(
                        isUnread ? PhosphorIconsFill.bellRinging : PhosphorIconsRegular.bell,
                        color: isUnread ? CeosColors.areaOdontologia : CeosColors.lightTextMuted,
                      ),
                      title: Text(
                        notif.titulo,
                        style: CeosTheme.heading(
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notif.mensaje, style: CeosTheme.body(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(notif.creadoEn, style: CeosTheme.dataMono(fontSize: 10, color: CeosColors.lightTextMuted)),
                        ],
                      ),
                      trailing: isUnread
                          ? IconButton(
                              icon: const Icon(PhosphorIconsRegular.checkCircle, size: 20, color: CeosColors.areaOdontologia),
                              tooltip: 'Marcar como leída',
                              onPressed: () async {
                                try {
                                  await ref.read(notificacionesRepositoryProvider).marcarLeida(notif.id);
                                  ref.invalidate(notificacionesProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            )
                          : null,
                      onTap: () async {
                        if (isUnread) {
                          try {
                            await ref.read(notificacionesRepositoryProvider).marcarLeida(notif.id);
                            ref.invalidate(notificacionesProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const SkeletonListaMateriales(count: 5),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: CeosColors.statusDanger),
                    const SizedBox(height: 12),
                    Text('Error al cargar notificaciones: $e', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(notificacionesProvider),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 18),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
