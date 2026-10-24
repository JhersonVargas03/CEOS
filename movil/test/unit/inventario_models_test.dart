import 'package:flutter_test/flutter_test.dart';
import 'package:ceos_app/models/inventario_models.dart';

void main() {
  group('Inventario Models Unit Tests (HU-412, HU-413, HU-418)', () {
    test('MaterialModel calcula correctamente banderas de stock crítico y bajo', () {
      final jsonCritico = {
        'id': 1,
        'nombre': 'Anestesia Lidocaína 2%',
        'categoria_id': 1,
        'categoria_nombre': 'Anestésicos',
        'area_id': 1,
        'area_nombre': 'Odontología',
        'unidad_medida': 'ampollas',
        'stock_total': 2,
        'stock_minimo': 10,
        'stock_optimo': 50,
      };

      final matCritico = MaterialModel.fromJson(jsonCritico);
      expect(matCritico.esCritico, true);
      expect(matCritico.esBajo, false);

      final jsonBajo = {
        'id': 2,
        'nombre': 'Guantes de Látex M',
        'categoria_id': 2,
        'categoria_nombre': 'Descartables',
        'area_id': 1,
        'area_nombre': 'Odontología',
        'unidad_medida': 'cajas',
        'stock_total': 8,
        'stock_minimo': 10,
        'stock_optimo': 30,
      };

      final matBajo = MaterialModel.fromJson(jsonBajo);
      expect(matBajo.esCritico, false);
      expect(matBajo.esBajo, true);
    });

    test('LoteModel identifica lotes vencidos y por vencer', () {
      final jsonVencido = {
        'id': 10,
        'material_id': 1,
        'numero_lote': 'LOT-2023-01',
        'cantidad': 15,
        'fecha_caducidad': '2023-05-15',
        'fecha_ingreso': '2023-01-10',
        'es_vencido': true,
        'por_vencer': false,
      };

      final lote = LoteModel.fromJson(jsonVencido);
      expect(lote.esVencido, true);
      expect(lote.numeroLote, 'LOT-2023-01');
    });

    test('SolicitudModel valida estado pendiente y acciones permitidas', () {
      final jsonPendiente = {
        'id': 101,
        'material_id': 1,
        'material_nombre': 'Sutura Quirúrgica 3-0',
        'usuario_id': 5,
        'usuario_nombre': 'Dr. Pérez',
        'cantidad': 20,
        'motivo': 'Sin stock disponible',
        'estado': 'pendiente',
        'creado_en': '2026-08-20T10:00:00Z',
      };

      final sol = SolicitudModel.fromJson(jsonPendiente);
      expect(sol.esPendiente, true);
      expect(sol.estado, 'pendiente');
    });
  });
}
