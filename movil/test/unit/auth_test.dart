import 'package:flutter_test/flutter_test.dart';
import 'package:ceos_app/models/usuario_model.dart';
import 'package:ceos_app/widgets/validador_password_en_vivo.dart';

void main() {
  group('Password Policy Unit Tests (HU-405, HU-406)', () {
    test('Valida correctamente los 5 requisitos de contraseña segura', () {
      // Too short
      var res = ValidadorPasswordEnVivo.validar('Ab1!');
      expect(res.tieneMinimo8, false);
      expect(res.esValida, false);

      // Missing uppercase
      res = ValidadorPasswordEnVivo.validar('password123!');
      expect(res.tieneMayuscula, false);
      expect(res.esValida, false);

      // Missing lowercase
      res = ValidadorPasswordEnVivo.validar('PASSWORD123!');
      expect(res.tieneMinuscula, false);
      expect(res.esValida, false);

      // Missing number
      res = ValidadorPasswordEnVivo.validar('Password!@#');
      expect(res.tieneNumero, false);
      expect(res.esValida, false);

      // Missing symbol
      res = ValidadorPasswordEnVivo.validar('Password123');
      expect(res.tieneSimbolo, false);
      expect(res.esValida, false);

      // Valid strong password
      res = ValidadorPasswordEnVivo.validar('CeosPass2026!');
      expect(res.tieneMinimo8, true);
      expect(res.tieneMayuscula, true);
      expect(res.tieneMinuscula, true);
      expect(res.tieneNumero, true);
      expect(res.tieneSimbolo, true);
      expect(res.esValida, true);
    });
  });

  group('UsuarioModel Unit Tests (HU-404, HU-410)', () {
    test('Parsea correctamente JSON de usuario activo con roles y permisos', () {
      final json = {
        'id': 1,
        'username': 'doctor.garcia',
        'correo_interno': 'd.garcia@ceos.local',
        'telefono': '+56912345678',
        'activo': true,
        'primer_login_completado': true,
        'roles': ['Odontólogo', 'Gestor de Inventario'],
        'permisos': ['ver_materiales', 'registrar_salida', 'crear_solicitud'],
        'session_version': 1,
      };

      final usuario = UsuarioModel.fromJson(json);

      expect(usuario.id, 1);
      expect(usuario.username, 'doctor.garcia');
      expect(usuario.activo, true);
      expect(usuario.primerLoginCompletado, true);
      expect(usuario.esSuperadmin, false);
      expect(usuario.tienePermiso('ver_materiales'), true);
      expect(usuario.tienePermiso('ajustar_inventario'), false);
      expect(usuario.rolPrincipal, 'Odontólogo');
    });

    test('Superadmin reconoce permisos globales automáticamente', () {
      final json = {
        'id': 99,
        'username': 'superadmin',
        'correo_interno': 'admin@ceos.local',
        'activo': true,
        'primer_login_completado': true,
        'roles': ['Superadmin'],
        'permisos': [],
        'session_version': 1,
      };

      final usuario = UsuarioModel.fromJson(json);

      expect(usuario.esSuperadmin, true);
      expect(usuario.tienePermiso('cualquier_permiso_arbitrario'), true);
      expect(usuario.rolPrincipal, 'Superadmin');
    });
  });
}
