import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notificaciones_provider.dart';
import '../../widgets/item_actividad_reciente.dart';

class VistaRestringidaScreen extends ConsumerWidget {
  const VistaRestringidaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialRecienteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Restringido (Modo Consulta)'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.signOut),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner informativo de cuenta inactiva
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CeosColors.statusWarningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CeosColors.statusWarning.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsFill.info,
                      color: CeosColors.statusWarning,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cuenta Inactiva',
                            style: CeosTheme.heading(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: CeosColors.statusWarning,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tu cuenta ha sido desactivada. Puedes consultar tu historial de actividad y reportes personales.',
                            style: CeosTheme.body(
                              fontSize: 12,
                              color: CeosColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Opciones permitidas en modo congelado
              Text(
                'Opciones Disponibles',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologia.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.filePdf,
                      color: CeosColors.areaOdontologia,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Mis Reportes de Actividad',
                    style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Descargar PDF de tus movimientos pasados',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                  ),
                  trailing: const Icon(PhosphorIconsRegular.caretRight, size: 16),
                  onTap: () => context.push('/inventario/reportes'),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Mi Historial Registrado',
                style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              historialAsync.when(
                data: (historial) {
                  if (historial.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: Text(
                          'No hay registros en tu historial.',
                          style: CeosTheme.body(color: CeosColors.lightTextMuted),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: historial.map((mov) {
                      return ItemActividadReciente(movimiento: mov);
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Error al cargar historial: $e',
                  style: CeosTheme.body(color: CeosColors.statusDanger),
                ),
              ),
              const SizedBox(height: 32),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CeosColors.statusDanger,
                  side: const BorderSide(color: CeosColors.statusDanger),
                ),
                icon: const Icon(PhosphorIconsRegular.signOut),
                label: const Text('Cerrar Sesión'),
                onPressed: () {
                  ref.read(authNotifierProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
