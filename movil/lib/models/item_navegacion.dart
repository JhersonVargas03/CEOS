import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ItemNavegacion {
  final String label;
  final IconData icon;
  final String route;
  final String? permisoRequerido;
  final bool esExclusivoSuperadmin;

  const ItemNavegacion({
    required this.label,
    required this.icon,
    required this.route,
    this.permisoRequerido,
    this.esExclusivoSuperadmin = false,
  });

  bool puedeMostrar({
    required List<String> permisosUsuario,
    required bool esSuperadmin,
  }) {
    if (esExclusivoSuperadmin && !esSuperadmin) {
      return false;
    }
    if (permisoRequerido == null) {
      return true;
    }
    if (esSuperadmin) {
      return true;
    }
    if (permisosUsuario.contains(permisoRequerido)) {
      return true;
    }
    if (permisoRequerido == 'ver_dashboard' && permisosUsuario.contains('ver_reportes_globales')) {
      return true;
    }
    if (permisoRequerido == 'generar_reportes' && permisosUsuario.contains('ver_reportes_globales')) {
      return true;
    }
    return false;
  }
}

class CatalogoNavegacion {
  CatalogoNavegacion._();

  // Bottom Nav Master List
  static const List<ItemNavegacion> bottomNavItems = [
    ItemNavegacion(
      label: 'Inicio',
      icon: PhosphorIconsRegular.house,
      route: '/home',
    ),
    ItemNavegacion(
      label: 'Inventario',
      icon: PhosphorIconsRegular.package,
      route: '/inventario',
    ),
    ItemNavegacion(
      label: 'Entrada',
      icon: PhosphorIconsRegular.arrowSquareIn,
      route: '/inventario/entrada',
      permisoRequerido: 'registrar_entrada',
    ),
    ItemNavegacion(
      label: 'Salida',
      icon: PhosphorIconsRegular.arrowSquareOut,
      route: '/inventario/salida',
      permisoRequerido: 'registrar_salida',
    ),
    ItemNavegacion(
      label: 'Solicitudes',
      icon: PhosphorIconsRegular.tray,
      route: '/inventario/solicitudes',
      permisoRequerido: 'solicitar_material',
    ),
  ];

  // Administración Options Master List
  static const List<ItemNavegacion> adminItems = [
    ItemNavegacion(
      label: 'Gestión de Usuarios',
      icon: PhosphorIconsRegular.users,
      route: '/admin/usuarios',
      permisoRequerido: 'gestionar_usuarios',
    ),
    ItemNavegacion(
      label: 'Roles y Permisos',
      icon: PhosphorIconsRegular.shieldCheck,
      route: '/admin/roles',
      permisoRequerido: 'gestionar_roles',
    ),
    ItemNavegacion(
      label: 'Configuración del Sistema',
      icon: PhosphorIconsRegular.gear,
      route: '/admin/configuracion',
      esExclusivoSuperadmin: true,
    ),
    ItemNavegacion(
      label: 'Respaldo de Base de Datos',
      icon: PhosphorIconsRegular.database,
      route: '/admin/backup',
      esExclusivoSuperadmin: true,
    ),
    ItemNavegacion(
      label: 'Dashboard y Estadísticas',
      icon: PhosphorIconsRegular.chartBar,
      route: '/inventario/dashboard',
      permisoRequerido: 'ver_dashboard',
    ),
    ItemNavegacion(
      label: 'Reportes PDF',
      icon: PhosphorIconsRegular.filePdf,
      route: '/inventario/reportes',
      permisoRequerido: 'generar_reportes',
    ),
    ItemNavegacion(
      label: 'Gestión de Inventario (Catálogo)',
      icon: PhosphorIconsRegular.stack,
      route: '/inventario/gestion',
      permisoRequerido: 'gestionar_catalogo_inventario',
    ),
    ItemNavegacion(
      label: 'Auditoría del Sistema',
      icon: PhosphorIconsRegular.clipboardText,
      route: '/admin/auditoria',
      permisoRequerido: 'ver_reportes_globales',
    ),
  ];
}
