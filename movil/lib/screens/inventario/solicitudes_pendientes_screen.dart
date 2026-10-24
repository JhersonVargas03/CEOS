import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/inventario_models.dart';
import '../../providers/inventario_providers.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/ceos_shimmer.dart';

class SolicitudesPendientesScreen extends ConsumerWidget {
  const SolicitudesPendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(solicitudesPendientesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          tooltip: 'Atrás',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text('Bandeja de Solicitudes Pendientes'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(solicitudesPendientesProvider),
          child: pendientesAsync.when(
            data: (solicitudes) {
              if (solicitudes.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          PhosphorIconsFill.checkCircle,
                          size: 48,
                          color: CeosColors.statusSuccess,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay solicitudes pendientes por resolver.',
                          style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Todas las peticiones del personal han sido atendidas.',
                          style: CeosTheme.body(color: CeosColors.lightTextSecondary),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CeosColors.statusWarningLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${sol.cantidad} unidades',
                                  style: CeosTheme.dataMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: CeosColors.statusWarning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Solicitado por: ${sol.usuarioNombre} • Motivo: ${sol.motivo}',
                            style: CeosTheme.body(fontSize: 13, color: CeosColors.lightTextSecondary),
                          ),
                          if (sol.comentario != null && sol.comentario!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Nota: "${sol.comentario}"',
                              style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextMuted),
                            ),
                          ],
                          const Divider(height: 20),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CeosColors.statusDanger,
                                  side: const BorderSide(color: CeosColors.statusDanger),
                                ),
                                icon: const Icon(PhosphorIconsRegular.xCircle, size: 16),
                                label: const Text('Rechazar'),
                                onPressed: () => _abrirModalResolucion(context, ref, sol, 'rechazar'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CeosColors.statusSuccess,
                                ),
                                icon: const Icon(PhosphorIconsRegular.checkCircle, size: 16),
                                label: const Text('Aprobar'),
                                onPressed: () => _abrirModalResolucion(context, ref, sol, 'aprobar'),
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
            loading: () => const SkeletonListaMateriales(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
    );
  }

  void _abrirModalResolucion(
    BuildContext context,
    WidgetRef ref,
    SolicitudModel solicitud,
    String accion,
  ) {
    final comentarioController = TextEditingController();
    final isRechazo = accion == 'rechazar';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? modalError;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isRechazo ? 'Rechazar Solicitud' : 'Aprobar Solicitud'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isRechazo ? "Rechazo" : "Aprobación"} de ${solicitud.cantidad} un. de ${solicitud.materialNombre} para ${solicitud.usuarioNombre}.',
                      style: CeosTheme.body(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: comentarioController,
                      enabled: !isSubmitting,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: isRechazo
                            ? 'Motivo de rechazo (obligatorio) *'
                            : 'Comentario de aprobación (opcional)',
                        hintText: isRechazo
                            ? 'ej. Hay stock en bodega 2 / se comprará en pedido mensual'
                            : 'ej. Aprobado para retiro inmediato',
                      ),
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        modalError!,
                        style: CeosTheme.body(fontSize: 12, color: CeosColors.statusDanger),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRechazo ? CeosColors.statusDanger : CeosColors.statusSuccess,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final comentario = comentarioController.text.trim();
                          if (isRechazo && comentario.isEmpty) {
                            setModalState(() {
                              modalError = 'Debes ingresar una justificación para rechazar la solicitud.';
                            });
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            modalError = null;
                          });

                          try {
                            final repo = ref.read(inventarioRepositoryProvider);
                            await repo.resolverSolicitud(
                              solicitudId: solicitud.id,
                              accion: accion,
                              comentarioResolucion: comentario.isNotEmpty ? comentario : null,
                            );

                            ref.invalidate(solicitudesPendientesProvider);

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Solicitud ${isRechazo ? "rechazada" : "aprobada"} exitosamente.'),
                                  backgroundColor: isRechazo ? CeosColors.statusDanger : CeosColors.statusSuccess,
                                ),
                              );
                            }
                          } on AppException catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              modalError = e.message;
                            });
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              modalError = 'Error: $e';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isRechazo ? 'Confirmar Rechazo' : 'Confirmar Aprobación'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => comentarioController.dispose());
  }
}
