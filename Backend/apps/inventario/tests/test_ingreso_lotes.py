from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote


class IngresoLotesEpica2BTestCase(TestCase):
    """T-205.1 a T-206.3 y T-205.T: Suite de tests para Épica 2.B — Ingreso de Lotes (Entradas)."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Usuario GestorInventario (posee el permiso registrar_entrada)
        self.gestor = Usuario.objects.create_user(
            username='GestorPruebas',
            correo_interno='gestor@clinica.com',
            password='Password123!'
        )
        # Asignar rol GestorInventario
        from apps.usuarios.models import Rol, UsuarioRol
        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.gestor, rol=rol_gestor)

        self.gestor_tokens = generar_tokens_para_usuario(self.gestor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')

        # Crear área, categoría y material base
        self.area = Area.objects.create(nombre='Farmacia')
        self.categoria = CategoriaMaterial.objects.create(nombre='Medicamentos')
        self.material = Material.objects.create(
            nombre='Amoxicilina 500mg',
            area=self.area,
            categoria=self.categoria,
            unidad_medida='caja'
        )

    def test_creacion_lote_con_y_sin_costo(self):
        """T-205.1 a T-205.4: Registro de lote con y sin costo, e inicialización de cantidad_disponible."""
        hoy = timezone.now().date()
        vencimiento = hoy + timedelta(days=180)

        # 1. Crear lote CON costo
        res_costo = self.client.post('/api/inventario/lotes', {
            'material_id': self.material.id,
            'codigo_lote': 'LOTE-1001',
            'cantidad_ingresada': 100,
            'costo': '150.50',
            'fecha_caducidad': str(vencimiento)
        }, format='json')
        self.assertEqual(res_costo.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res_costo.data['costo_registrado'])
        self.assertEqual(res_costo.data['cantidad_disponible'], 100)
        self.assertEqual(res_costo.data['cantidad_ingresada'], 100)

        # 2. Crear lote SIN costo
        res_sin_costo = self.client.post('/api/inventario/lotes', {
            'material_id': self.material.id,
            'codigo_lote': 'LOTE-1002',
            'cantidad_ingresada': 50,
            'fecha_caducidad': str(vencimiento)
        }, format='json')
        self.assertEqual(res_sin_costo.status_code, status.HTTP_201_CREATED)
        self.assertFalse(res_sin_costo.data['costo_registrado'])
        self.assertIsNone(res_sin_costo.data['costo'])

    def test_validacion_fechas_inconsistentes(self):
        """T-205.6: Rechazo de fechas caducidad/alerta inconsistentes."""
        hoy = timezone.now().date()
        ayer = hoy - timedelta(days=1)
        vencimiento = hoy + timedelta(days=30)
        alerta_posterior = vencimiento + timedelta(days=5)

        # Caducidad anterior a fecha ingreso
        res1 = self.client.post('/api/inventario/lotes', {
            'material_id': self.material.id,
            'codigo_lote': 'LOTE-ERR1',
            'cantidad_ingresada': 10,
            'fecha_ingreso': str(hoy),
            'fecha_caducidad': str(ayer)
        }, format='json')
        self.assertEqual(res1.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('fecha_caducidad', res1.data['detalles'])

        # Alerta de vencimiento posterior a caducidad
        res2 = self.client.post('/api/inventario/lotes', {
            'material_id': self.material.id,
            'codigo_lote': 'LOTE-ERR2',
            'cantidad_ingresada': 10,
            'fecha_caducidad': str(vencimiento),
            'fecha_alerta_vencimiento': str(alerta_posterior)
        }, format='json')
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('fecha_alerta_vencimiento', res2.data['detalles'])

    def test_registro_auditoria_ingreso_lote(self):
        """T-205.5: Registro automático en auditoría tras ingreso de lote."""
        res = self.client.post('/api/inventario/lotes', {
            'material_id': self.material.id,
            'codigo_lote': 'LOTE-AUD1',
            'cantidad_ingresada': 200
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        auditoria = RegistroAuditoria.objects.filter(accion='INGRESO_LOTE').last()
        self.assertIsNotNone(auditoria)
        self.assertEqual(auditoria.usuario, self.gestor)
        self.assertEqual(auditoria.detalles['codigo_lote'], 'LOTE-AUD1')

    def test_listado_lotes_ordenado_y_alerta_activa(self):
        """T-206.1 a T-206.3: Listado de lotes por material ordenado por vencimiento, filtro de agotados y alerta activa."""
        hoy = timezone.now().date()
        venc_proximo = hoy + timedelta(days=5)
        venc_lejano = hoy + timedelta(days=60)
        venc_pasado = hoy - timedelta(days=2)

        # Lote 1: vence en 60 días (alerta inactiva)
        l1 = Lote.objects.create(
            material=self.material, codigo_lote='LOT-LEJANO',
            cantidad_ingresada=30, cantidad_disponible=30,
            fecha_caducidad=venc_lejano,
            fecha_alerta_vencimiento=hoy + timedelta(days=40)
        )

        # Lote 2: vence en 5 días (alerta activa por fecha_alerta_vencimiento <= hoy)
        l2 = Lote.objects.create(
            material=self.material, codigo_lote='LOT-PROXIMO',
            cantidad_ingresada=20, cantidad_disponible=20,
            fecha_caducidad=venc_proximo,
            fecha_alerta_vencimiento=hoy - timedelta(days=1)
        )

        # Lote 3: agotado (cantidad_disponible = 0)
        l3 = Lote.objects.create(
            material=self.material, codigo_lote='LOT-AGOTADO',
            cantidad_ingresada=10, cantidad_disponible=0,
            fecha_caducidad=venc_pasado
        )

        # GET /inventario/materiales/{id}/lotes (sin agotados)
        res = self.client.get(f'/api/inventario/materiales/{self.material.id}/lotes')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 2)  # Excluye agotado

        # Verificar ordenamiento por fecha_caducidad asc (l2 primero que l1)
        self.assertEqual(res.data[0]['codigo_lote'], 'LOT-PROXIMO')
        self.assertTrue(res.data[0]['alerta_activa'])
        self.assertEqual(res.data[1]['codigo_lote'], 'LOT-LEJANO')
        self.assertFalse(res.data[1]['alerta_activa'])

        # GET con incluir_agotados=true
        res_agotados = self.client.get(f'/api/inventario/materiales/{self.material.id}/lotes?incluir_agotados=true')
        self.assertEqual(res_agotados.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_agotados.data), 3)
