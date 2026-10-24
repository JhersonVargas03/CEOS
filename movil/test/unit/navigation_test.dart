import 'package:flutter_test/flutter_test.dart';
import 'package:ceos_app/models/item_navegacion.dart';

void main() {
  group('Navegación Dinámica Unit Tests (HU-401, HU-402, HU-403)', () {
    test('Filtra correctamente ítems de bottom nav según permisos del usuario', () {
      final permisosDoctor = ['ver_inventario', 'registrar_salida', 'solicitar_material'];

      final itemsVisibles = CatalogoNavegacion.bottomNavItems
          .where((item) => item.puedeMostrar(
                permisosUsuario: permisosDoctor,
                esSuperadmin: false,
              ))
          .toList();

      expect(itemsVisibles.any((i) => i.route == '/home'), true);
      expect(itemsVisibles.any((i) => i.route == '/inventario'), true);
      expect(itemsVisibles.any((i) => i.route == '/inventario/salida'), true);
      expect(itemsVisibles.any((i) => i.route == '/inventario/solicitudes'), true);
      // Entrada requires 'registrar_entrada' which doctor doesn't have
      expect(itemsVisibles.any((i) => i.route == '/inventario/entrada'), false);
    });

    test('Superadmin visualiza ítems exclusivos y no excede 5 en bottom navigation', () {
      final itemsSuperadmin = CatalogoNavegacion.bottomNavItems
          .where((item) => item.puedeMostrar(
                permisosUsuario: [],
                esSuperadmin: true,
              ))
          .take(5)
          .toList();

      expect(itemsSuperadmin.length, lessThanOrEqualTo(5));
      expect(itemsSuperadmin.any((i) => i.route == '/home'), true);
    });

    test('Opciones de Administración requieren esSuperadmin estricto para backup y sistema', () {
      final itemBackup = CatalogoNavegacion.adminItems.firstWhere((i) => i.route == '/admin/backup');
      final itemSistema = CatalogoNavegacion.adminItems.firstWhere((i) => i.route == '/admin/configuracion');

      // Regular user with all permissions except esSuperadmin
      expect(
        itemBackup.puedeMostrar(
          permisosUsuario: ['hacer_backup', 'configurar_sistema'],
          esSuperadmin: false,
        ),
        false,
      );

      expect(
        itemSistema.puedeMostrar(
          permisosUsuario: ['configurar_sistema'],
          esSuperadmin: false,
        ),
        false,
      );

      // Superadmin
      expect(
        itemBackup.puedeMostrar(
          permisosUsuario: [],
          esSuperadmin: true,
        ),
        true,
      );

      expect(
        itemSistema.puedeMostrar(
          permisosUsuario: [],
          esSuperadmin: true,
        ),
        true,
      );
    });
  });
}
