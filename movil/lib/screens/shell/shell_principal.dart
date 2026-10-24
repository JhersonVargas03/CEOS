import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/ceos_colors.dart';
import '../../core/theme/ceos_theme.dart';
import '../../models/item_navegacion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permisos_provider.dart';
import '../../widgets/skeleton_home.dart';

class ShellPrincipal extends ConsumerWidget {
  final Widget child;
  final String? location;

  const ShellPrincipal({
    super.key,
    required this.child,
    this.location,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permisosAsync = ref.watch(permisosEfectivosProvider);
    final esSuperadmin = ref.watch(esSuperadminProvider);

    return permisosAsync.when(
      data: (permisos) {
        // Filter items dynamically by effective permissions (HU-401)
        final visibleNavItems = CatalogoNavegacion.bottomNavItems
            .where((item) => item.puedeMostrar(
                  permisosUsuario: permisos,
                  esSuperadmin: esSuperadmin,
                ))
            .take(5) // Max 5 items in bottom nav (HU-401)
            .toList();

        final currentLoc = location ??
            (() {
              try {
                return GoRouterState.of(context).matchedLocation;
              } catch (_) {
                return '';
              }
            })();

        int currentIndex = 0;
        int maxMatchLength = -1;
        for (int i = 0; i < visibleNavItems.length; i++) {
          final itemRoute = visibleNavItems[i].route;
          if (currentLoc == itemRoute) {
            currentIndex = i;
            break;
          } else if (currentLoc.startsWith(itemRoute) && itemRoute != '/home' && itemRoute.length > maxMatchLength) {
            maxMatchLength = itemRoute.length;
            currentIndex = i;
          }
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: visibleNavItems.length > 1
              ? BottomNavigationBar(
                  currentIndex: currentIndex.clamp(0, visibleNavItems.length - 1),
                  onTap: (index) {
                    final targetRoute = visibleNavItems[index].route;
                    context.go(targetRoute);
                  },
                  items: visibleNavItems.map((item) {
                    return BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    );
                  }).toList(),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: SafeArea(child: SkeletonHome()), // Anti-flicker skeleton (HU-403)
      ),
      error: (err, stack) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    PhosphorIconsFill.warningCircle,
                    size: 48,
                    color: CeosColors.statusDanger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar permisos',
                    style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No se pudieron validar los permisos de tu cuenta.',
                    style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                    label: const Text('Reintentar'),
                    onPressed: () {
                      ref.invalidate(permisosEfectivosProvider);
                      ref.read(authNotifierProvider.notifier).refreshProfile();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
