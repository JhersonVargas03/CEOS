import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/administracion_screen.dart';
import '../../screens/admin/backup_screen.dart';
import '../../screens/admin/configuracion_sistema_screen.dart';
import '../../screens/admin/crear_usuario_screen.dart';
import '../../screens/admin/credenciales_generadas_screen.dart';
import '../../screens/admin/detalle_usuario_screen.dart';
import '../../screens/admin/editar_rol_screen.dart';
import '../../screens/admin/auditoria_screen.dart';
import '../../screens/admin/lista_roles_screen.dart';
import '../../screens/admin/lista_usuarios_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/primer_login_screen.dart';
import '../../screens/auth/recuperar_password_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/vista_restringida_screen.dart';
import '../../screens/inventario/ajuste_inventario_screen.dart';
import '../../screens/inventario/crear_solicitud_screen.dart';
import '../../screens/inventario/dashboard_screen.dart';
import '../../screens/inventario/detalle_material_screen.dart';
import '../../screens/inventario/editar_solicitud_screen.dart';
import '../../screens/inventario/generar_reporte_pdf_screen.dart';
import '../../screens/inventario/lista_materiales_screen.dart';
import '../../screens/inventario/mis_solicitudes_screen.dart';
import '../../screens/inventario/nueva_entrada_screen.dart';
import '../../screens/inventario/nueva_salida_screen.dart';
import '../../screens/inventario/solicitudes_pendientes_screen.dart';
import '../../models/inventario_models.dart';
import '../../screens/inventario/crear_editar_area_screen.dart';
import '../../screens/inventario/crear_editar_categoria_screen.dart';
import '../../screens/inventario/crear_editar_material_screen.dart';
import '../../screens/inventario/gestion_inventario_screen.dart';
import '../../screens/inventario/todas_solicitudes_screen.dart';
import '../../screens/notificaciones/notificaciones_screen.dart';
import '../../screens/perfil/perfil_screen.dart';
import '../../screens/shell/shell_principal.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  // Definida dentro del provider para que sea unica por instancia y no
  // choque entre rebuilds (evita "GlobalKey used multiple times").
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc.startsWith('/recuperar-password');

      if (authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.error) {
        if (!isAuthRoute) return '/login';
        return null;
      }

      if (authState.status == AuthStatus.requiresFirstLogin) {
        if (loc != '/primer-login') return '/primer-login';
        return null;
      }

      if (authState.user != null && !authState.user!.activo) {
        if (loc != '/vista-restringida' && !loc.startsWith('/inventario/reportes')) {
          return '/vista-restringida';
        }
        return null;
      }

      if (authState.status == AuthStatus.authenticated && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/primer-login',
        builder: (context, state) => const PrimerLoginScreen(),
      ),
      GoRoute(
        path: '/recuperar-password',
        builder: (context, state) => const RecuperarPasswordScreen(),
      ),
      GoRoute(
        path: '/vista-restringida',
        builder: (context, state) => const VistaRestringidaScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (context, state) => '/home',
      ),
      ShellRoute(
        builder: (context, state, child) => ShellPrincipal(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/inventario',
            builder: (context, state) => const ListaMaterialesScreen(),
          ),
          GoRoute(
            path: '/inventario/entrada',
            builder: (context, state) {
              final matId = int.tryParse(state.uri.queryParameters['materialId'] ?? '');
              return NuevaEntradaScreen(initialMaterialId: matId);
            },
          ),
          GoRoute(
            path: '/inventario/salida',
            builder: (context, state) {
              final matId = int.tryParse(state.uri.queryParameters['materialId'] ?? '');
              return NuevaSalidaScreen(initialMaterialId: matId);
            },
          ),
          GoRoute(
            path: '/inventario/solicitudes',
            builder: (context, state) => const MisSolicitudesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/inventario/material/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return DetalleMaterialScreen(materialId: id);
        },
      ),
      GoRoute(
        path: '/inventario/ajuste',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final matId = int.tryParse(state.uri.queryParameters['materialId'] ?? '');
          return AjusteInventarioScreen(initialMaterialId: matId);
        },
      ),
      GoRoute(
        path: '/inventario/solicitar',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final matId = int.tryParse(state.uri.queryParameters['materialId'] ?? '');
          return CrearSolicitudScreen(initialMaterialId: matId);
        },
      ),
      GoRoute(
        path: '/inventario/mis-solicitudes',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const MisSolicitudesScreen(),
      ),
      GoRoute(
        path: '/inventario/editar-solicitud/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return EditarSolicitudScreen(solicitudId: id);
        },
      ),
      GoRoute(
        path: '/inventario/resolver-solicitudes',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const SolicitudesPendientesScreen(),
      ),
      GoRoute(
        path: '/inventario/todas-solicitudes',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const TodasSolicitudesScreen(),
      ),
      GoRoute(
        path: '/inventario/reportes',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const GenerarReportePDFScreen(),
      ),
      GoRoute(
        path: '/inventario/dashboard',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/inventario/gestion',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const GestionInventarioScreen(),
      ),
      GoRoute(
        path: '/inventario/gestion/material/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final areaId = int.tryParse(state.uri.queryParameters['areaId'] ?? '');
          final catId = int.tryParse(state.uri.queryParameters['categoriaId'] ?? '');
          return CrearEditarMaterialScreen(
            initialAreaId: areaId,
            initialCategoriaId: catId,
          );
        },
      ),
      GoRoute(
        path: '/inventario/materiales/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final areaId = int.tryParse(state.uri.queryParameters['areaId'] ?? '');
          final catId = int.tryParse(state.uri.queryParameters['categoriaId'] ?? '');
          return CrearEditarMaterialScreen(
            initialAreaId: areaId,
            initialCategoriaId: catId,
          );
        },
      ),
      GoRoute(
        path: '/inventario/gestion/material/:id/editar',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final mat = state.extra is MaterialModel ? state.extra as MaterialModel : null;
          return CrearEditarMaterialScreen(materialId: id, material: mat);
        },
      ),
      GoRoute(
        path: '/inventario/materiales/:id/editar',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final mat = state.extra is MaterialModel ? state.extra as MaterialModel : null;
          return CrearEditarMaterialScreen(materialId: id, material: mat);
        },
      ),
      GoRoute(
        path: '/inventario/gestion/categoria/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final areaId = int.tryParse(state.uri.queryParameters['areaId'] ?? '');
          return CrearEditarCategoriaScreen(initialAreaId: areaId);
        },
      ),
      GoRoute(
        path: '/inventario/gestion/categoria/:id/editar',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final cat = state.extra is CategoriaModel ? state.extra as CategoriaModel : null;
          return CrearEditarCategoriaScreen(categoriaId: id, categoria: cat);
        },
      ),
      GoRoute(
        path: '/inventario/gestion/area/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CrearEditarAreaScreen(),
      ),
      GoRoute(
        path: '/inventario/gestion/area/:id/editar',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final area = state.extra is AreaModel ? state.extra as AreaModel : null;
          return CrearEditarAreaScreen(areaId: id, area: area);
        },
      ),
      GoRoute(
        path: '/administracion',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AdministracionScreen(),
      ),
      GoRoute(
        path: '/admin/usuarios',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const ListaUsuariosScreen(),
      ),
      GoRoute(
        path: '/admin/usuarios/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const CrearUsuarioScreen(),
      ),
      GoRoute(
        path: '/admin/usuarios/credenciales-generadas',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CredencialesGeneradasScreen(
            username: extra['username'] as String? ?? 'Usuario',
            passwordTemporal: extra['password_temporal'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/admin/usuarios/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return DetalleUsuarioScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/admin/roles',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const ListaRolesScreen(),
      ),
      GoRoute(
        path: '/admin/roles/crear',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const EditarRolScreen(),
      ),
      GoRoute(
        path: '/admin/roles/editar/:id',
        parentNavigatorKey: rootKey,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return EditarRolScreen(rolId: id);
        },
      ),
      GoRoute(
        path: '/admin/configuracion',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const ConfiguracionSistemaScreen(),
      ),
      GoRoute(
        path: '/admin/backup',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/admin/auditoria',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const AuditoriaScreen(),
      ),
      GoRoute(
        path: '/notificaciones',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const NotificacionesScreen(),
      ),
      GoRoute(
        path: '/perfil',
        parentNavigatorKey: rootKey,
        builder: (context, state) => const PerfilScreen(),
      ),
    ],
  );
});
