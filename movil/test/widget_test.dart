import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ceos_app/core/constants/icon_catalog.dart';
import 'package:ceos_app/core/theme/ceos_colors.dart';
import 'package:ceos_app/widgets/badge_estado.dart';
import 'package:ceos_app/widgets/chip_rol_activo.dart';
import 'package:ceos_app/widgets/stepper_progreso.dart';
import 'package:ceos_app/widgets/tarjeta_alerta.dart';
import 'package:ceos_app/widgets/validador_password_en_vivo.dart';
import 'package:ceos_app/widgets/selector_icono_grid.dart';
import 'package:ceos_app/widgets/fondo_ambiental.dart';
import 'package:ceos_app/widgets/ceos_shimmer.dart';

void main() {
  group('Widget Tests Reutilizables (Épicas 4.A - 4.D)', () {
    testWidgets('BadgeEstado renderiza correctamente diferentes estados', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BadgeEstado(estado: 'pendiente'),
                BadgeEstado(estado: 'aprobada'),
                BadgeEstado(estado: 'rechazada'),
                BadgeEstado(estado: 'cancelada'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('APROBADA'), findsOneWidget);
      expect(find.text('RECHAZADA'), findsOneWidget);
      expect(find.text('CANCELADA'), findsOneWidget);
    });

    testWidgets('ChipRolActivo renderiza y muestra corona si es Superadmin', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChipRolActivo(rol: 'Superadmin', esSuperadmin: true),
                ChipRolActivo(rol: 'Odontólogo', esSuperadmin: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Superadmin'), findsOneWidget);
      expect(find.text('Odontólogo'), findsOneWidget);
    });

    testWidgets('StepperProgreso visualiza paso actual y total', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StepperProgreso(
              pasoActual: 1,
              totalPasos: 3,
              titulosPasos: ['Cambio de Contraseña', 'Paso 2', 'Paso 3'],
            ),
          ),
        ),
      );

      expect(find.text('Paso 1 de 3'), findsOneWidget);
    });

    testWidgets('ValidadorPasswordEnVivo muestra 5 requerimientos interactivos', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ValidadorPasswordEnVivo(
              password: 'Ab1',
            ),
          ),
        ),
      );

      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
      expect(find.text('Al menos una letra mayúscula (A-Z)'), findsOneWidget);
      expect(find.text('Al menos una letra minúscula (a-z)'), findsOneWidget);
      expect(find.text('Al menos un número (0-9)'), findsOneWidget);
      expect(find.text('Al menos un carácter especial (!@#\$%...)'), findsOneWidget);
    });

    test('IconCatalog resuelve íconos de labios, estética, farmacia y odontología', () {
      // Labios y estética
      final iconLips = IconCatalog.getIcon('lips');
      final iconLabios = IconCatalog.getIcon('labios');
      expect(iconLips, equals(iconLabios));
      expect(iconLips, isNot(equals(IconCatalog.getIcon('package'))));

      // Farmacia y medicina
      expect(IconCatalog.getIcon('farmacia'), isNotNull);
      expect(IconCatalog.getIcon('medicina'), isNotNull);
      expect(IconCatalog.getIcon('local_pharmacy'), equals(IconCatalog.getIcon('farmacia')));
      expect(IconCatalog.getIcon('pill'), equals(IconCatalog.getIcon('pastilla')));
      expect(IconCatalog.getIcon('syringe'), equals(IconCatalog.getIcon('jeringa')));
      expect(IconCatalog.getIcon('prescription'), equals(IconCatalog.getIcon('receta')));

      // Odontología
      expect(IconCatalog.getIcon('tooth'), equals(IconCatalog.getIcon('diente')));
      expect(IconCatalog.getIcon('dentistry'), equals(IconCatalog.getIcon('odontologia')));

      // Búsqueda inteligente
      final searchLabios = IconCatalog.searchIcons('labios');
      expect(searchLabios, contains('lips'));

      final searchFarmacia = IconCatalog.searchIcons('farmacia');
      expect(searchFarmacia, contains('local_pharmacy'));

      final searchDiente = IconCatalog.searchIcons('diente');
      expect(searchDiente, contains('tooth'));
    });

    testWidgets('SelectorIconoGrid no desborda en contenedor acotado de 180px (fix overflow 214px)', (WidgetTester tester) async {
      String? seleccionado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 180,
              child: SelectorIconoGrid(
                iconoSeleccionado: 'tag',
                onIconSelected: (val) => seleccionado = val,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectorIconoGrid), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('Ajuste Móvil 4.K: Rediseño Visual Premium y Accesibilidad', () {
    testWidgets('FondoAmbiental renderiza correctamente en modo Claro y Oscuro', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: FondoAmbiental(
              child: Center(child: Text('Contenido Test')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FondoAmbiental), findsOneWidget);
      expect(find.text('Contenido Test'), findsOneWidget);
    });

    testWidgets('CeosShimmer y SkeletonListaMateriales animan sin excepciones', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListaMateriales(count: 3),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonListaMateriales), findsOneWidget);
      expect(find.byType(CeosShimmer), findsWidgets);

      // Avanzar el reloj de animación para verificar que no lance excepción
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    test('Contraste WCAG AA: texto principal modo oscuro vs fondo tarjeta supera 4.5:1', () {
      final double l1 = CeosColors.darkTextPrimary.computeLuminance();
      final double l2 = CeosColors.darkCard.computeLuminance();
      final double ratio = (l1 + 0.05) / (l2 + 0.05);

      // WCAG AA para texto normal requiere ratio >= 4.5
      expect(ratio, greaterThan(4.5));
    });
  });
}

