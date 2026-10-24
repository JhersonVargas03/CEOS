import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/item_navegacion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permisos_provider.dart';
import '../../widgets/chip_rol_activo.dart';

class AdministracionScreen extends ConsumerWidget {
  const AdministracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Card Profile Info
              if (user != null) ...[
                Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/perfil'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: CeosColors.areaOdontologiaLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsFill.userCircle,
                              size: 32,
                              color: CeosColors.areaOdontologia,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nombreMostrado,
                                  style: CeosTheme.heading(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.correoInterno,
                                  style: CeosTheme.body(
                                    fontSize: 13,
                                    color: CeosColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ChipRolActivo(
                                  rol: user.rolPrincipal,
                                  esSuperadmin: user.esSuperadmin,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 20,
                            color: CeosColors.lightTextSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Módulos Administrativos',
                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              // Filtered List of Admin Options (HU-402)
              permisosAsync.when(
                data: (permisos) {
                  final opcionesVisibles = CatalogoNavegacion.adminItems.where(
                    (item) => item.puedeMostrar(
                      permisosUsuario: permisos,
                      esSuperadmin: esSuperadmin,
                    ),
                  ).toList();

                  if (opcionesVisibles.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.18)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.shieldSlash,
                            size: 40,
                            color: CeosColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Área Reservada',
                            style: CeosTheme.heading(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tu cuenta no cuenta con permisos administrativos (gestión de usuarios, roles o configuración). Si requieres acceso, solicita autorización a un Administrador.',
                            textAlign: TextAlign.center,
                            style: CeosTheme.body(
                              fontSize: 13,
                              color: CeosColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/home'),
                            icon: const Icon(PhosphorIconsRegular.house, size: 18),
                            label: const Text('Volver al Inicio'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: opcionesVisibles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = opcionesVisibles[index];

                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.esExclusivoSuperadmin
                                  ? CeosColors.roleSuperadmin.withOpacity(0.12)
                                  : CeosColors.areaOdontologia.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              item.icon,
                              color: item.esExclusivoSuperadmin
                                  ? CeosColors.roleSuperadmin
                                  : CeosColors.areaOdontologia,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.label,
                            style: CeosTheme.heading(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: Colors.grey,
                          ),
                          onTap: () => context.push(item.route),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Error al cargar permisos: $e',
                  style: CeosTheme.body(color: CeosColors.statusDanger),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Cuenta y Seguridad',
                style: CeosTheme.heading(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CeosColors.areaOdontologia.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      PhosphorIconsRegular.userGear,
                      color: CeosColors.areaOdontologia,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Mi Perfil y Seguridad',
                    style: CeosTheme.heading(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Editar datos personales, teléfono y contraseña',
                    style: CeosTheme.body(
                      fontSize: 12,
                      color: CeosColors.lightTextSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () => context.push('/perfil'),
                ),
              ),

              const SizedBox(height: 24),

              // Botón Cerrar Sesión
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: CeosColors.statusDanger,
                  side: const BorderSide(color: CeosColors.statusDanger),
                ),
                icon: const Icon(PhosphorIconsRegular.signOut),
                label: const Text('Cerrar Sesión'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Cerrar Sesión?'),
                      content: const Text('Tendrás que ingresar tus credenciales para volver a entrar.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CeosColors.statusDanger,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(authNotifierProvider.notifier).logout();
                            context.go('/login');
                          },
                          child: const Text('Cerrar Sesión'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
