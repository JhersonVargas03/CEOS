from decimal import Decimal
from django.utils import timezone
from rest_framework.test import APITestCase
from rest_framework import status

from apps.usuarios.models import Usuario, Rol, UsuarioRol, invalidar_cache_permisos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.inventario.models import Material, Area, CategoriaMaterial
from apps.inventario.models_lotes import Lote
from apps.inventario.models_movimientos import MovimientoSalida, MovimientoSalidaLote
from apps.inventario.models_solicitudes import SolicitudMaterial


class DashboardYGastosEpica2HTestCase(APITestCase):
    """
    Suite de pruebas automatizadas para la Épica 2.H — Dashboard y Reporte de Gastos (HU-220, HU-221, HU-222).
    """

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.user = Usuario.objects.create_user(
            username='inventario_user',
            correo_interno='user@clinica.com',
            password='Password123!'
        )
        rol_inv = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.user, rol=rol_inv)
        invalidar_cache_permisos(self.user)
        tokens = generar_tokens_para_usuario(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")

        # Datos base
        self.area1 = Area.objects.create(nombre='Cirugía')
        self.area2 = Area.objects.create(nombre='Ortodoncia')
        self.cat1 = CategoriaMaterial.objects.create(nombre='Consumibles')
        self.cat2 = CategoriaMaterial.objects.create(nombre='Instrumental')

        self.mat1 = Material.objects.create(
            nombre='Gasa Estéril',
            area=self.area1,
            categoria=self.cat1,
            stock_minimo=10
        )
        self.mat2 = Material.objects.create(
            nombre='Brackets Metálicos',
            area=self.area2,
            categoria=self.cat2,
            stock_minimo=5
        )

        # Lotes con y sin costo
        self.lote1 = Lote.objects.create(
            material=self.mat1,
            codigo_lote='L-GAS-01',
            cantidad_ingresada=100,
            cantidad_disponible=80,
            costo=Decimal('150.00'),
            costo_registrado=True,
            usuario_ingreso=self.user
        )
        self.lote2 = Lote.objects.create(
            material=self.mat2,
            codigo_lote='L-BRA-01',
            cantidad_ingresada=50,
            cantidad_disponible=50,
            costo=Decimal('500.00'),
            costo_registrado=True,
            usuario_ingreso=self.user
        )
        self.lote3_sin_costo = Lote.objects.create(
            material=self.mat1,
            codigo_lote='L-GAS-02',
            cantidad_ingresada=30,
            cantidad_disponible=30,
            costo=None,
            costo_registrado=False,
            usuario_ingreso=self.user
        )

        # Salidas de material
        mov1 = MovimientoSalida.objects.create(
            material=self.mat1,
            cantidad_total=20,
            usuario=self.user,
            motivo_destino='Uso en procedimiento'
        )
        MovimientoSalidaLote.objects.create(movimiento_salida=mov1, lote=self.lote1, cantidad_descontada=20)

        mov2 = MovimientoSalida.objects.create(
            material=self.mat1,
            cantidad_total=10,
            usuario=self.user,
            motivo_destino='Uso adicional'
        )
        MovimientoSalidaLote.objects.create(movimiento_salida=mov2, lote=self.lote1, cantidad_descontada=10)

        mov3 = MovimientoSalida.objects.create(
            material=self.mat2,
            cantidad_total=5,
            usuario=self.user,
            motivo_destino='Colocación ortodoncia'
        )
        MovimientoSalidaLote.objects.create(movimiento_salida=mov3, lote=self.lote2, cantidad_descontada=5)

        # Solicitudes de material
        SolicitudMaterial.objects.create(
            material=self.mat1,
            cantidad_solicitada=15,
            solicitante=self.user,
            motivo='reposicion_preventiva por alto consumo'
        )
        SolicitudMaterial.objects.create(
            material=self.mat2,
            cantidad_solicitada=10,
            solicitante=self.user,
            motivo='reposicion_preventiva de stock'
        )
        SolicitudMaterial.objects.create(
            material=self.mat1,
            cantidad_solicitada=5,
            solicitante=self.user,
            motivo='Urgencia clínica'
        )

    def test_materiales_mas_usados_ranking(self):
        """T-220.1 a T-220.3: GET /inventario/dashboard/mas-usados retorna ranking por SUM(cantidad)."""
        res = self.client.get('/api/inventario/dashboard/mas-usados')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        datos = res.data.get('materiales_mas_usados', [])
        self.assertGreaterEqual(len(datos), 2)
        # Gasa Estéril debe ser primero con total_usado = 30
        self.assertEqual(datos[0]['material_id'], self.mat1.id)
        self.assertEqual(datos[0]['total_usado'], 30)
        # Brackets Metálicos segundo con total_usado = 5
        self.assertEqual(datos[1]['material_id'], self.mat2.id)
        self.assertEqual(datos[1]['total_usado'], 5)

    def test_materiales_mas_usados_con_filtros(self):
        """T-220.2: Filtrado de materiales más usados por area_id."""
        res = self.client.get(f'/api/inventario/dashboard/mas-usados?area_id={self.area2.id}')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        datos = res.data.get('materiales_mas_usados', [])
        self.assertEqual(len(datos), 1)
        self.assertEqual(datos[0]['material_id'], self.mat2.id)

    def test_reposicion_preventiva(self):
        """T-221.1 a T-221.3: GET /inventario/dashboard/reposicion-preventiva filtra por motivo reposicion_preventiva."""
        res = self.client.get('/api/inventario/dashboard/reposicion-preventiva')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        datos = res.data.get('solicitudes_preventivas', [])
        self.assertEqual(len(datos), 2)
        mats_ids = [d['material_id'] for d in datos]
        self.assertIn(self.mat1.id, mats_ids)
        self.assertIn(self.mat2.id, mats_ids)

    def test_reporte_gastos_agrupado_y_porcentaje_incompleto(self):
        """T-222.1 a T-222.4: GET /inventario/reportes/gastos agrupa por categoría, material y calcula % incompleto."""
        res = self.client.get('/api/inventario/reportes/gastos')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        resumen = res.data.get('resumen_costos', {})

        self.assertEqual(resumen['total_lotes'], 3)
        self.assertEqual(resumen['lotes_sin_costo'], 1)
        # 1 / 3 = 33.33%
        self.assertEqual(resumen['porcentaje_costo_incompleto'], 33.33)
        self.assertEqual(resumen['total_gasto_global'], 650.00)

        # Gastos por categoría
        cats = res.data.get('gastos_por_categoria', [])
        self.assertEqual(len(cats), 2)
        # Instrumental = 500.00, Consumibles = 150.00
        self.assertEqual(cats[0]['total_gasto'], 500.0)
        self.assertEqual(cats[1]['total_gasto'], 150.0)

        # Gastos por material
        mats = res.data.get('gastos_por_material', [])
        self.assertEqual(len(mats), 2)
