from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, UsuarioRol
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.models_movimientos import MovimientoSalida, MovimientoSalidaLote


class SalidasFEFOEpica2CTestCase(TestCase):
    """T-207.1 a T-208.3 y T-207.T: Suite de tests para Épica 2.C — Salidas de Material (FEFO)."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Usuario GestorInventario (posee registrar_salida y ajustar_inventario)
        self.gestor = Usuario.objects.create_user(
            username='GestorSalidas',
            correo_interno='gestorsalidas@clinica.com',
            password='Password123!'
        )
        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.gestor, rol=rol_gestor)

        # Usuario Doctor (posee registrar_salida pero NO ajustar_inventario)
        self.doctor = Usuario.objects.create_user(
            username='DoctorSalidas',
            correo_interno='doctorsalidas@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)

        # Autenticar como Gestor por defecto
        self.gestor_tokens = generar_tokens_para_usuario(self.gestor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')

        # Área, categoría y material
        self.area = Area.objects.create(nombre='Quirófano')
        self.categoria = CategoriaMaterial.objects.create(nombre='Insumos Quirúrgicos')
        self.material = Material.objects.create(
            nombre='Gasa Estéril',
            area=self.area,
            categoria=self.categoria,
            unidad_medida='paquete',
            stock_minimo=10
        )

    def test_salida_repartida_entre_lotes_fefo(self):
        """T-207.1 a T-207.5: Salida que se distribuye correctamente entre dos lotes por orden de vencimiento FEFO."""
        hoy = timezone.now().date()
        venc_proximo = hoy + timedelta(days=10)
        venc_lejano = hoy + timedelta(days=40)

        # Lote A: Vence primero (10 días), 5 disponibles
        lote_a = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-A-10',
            cantidad_ingresada=5,
            cantidad_disponible=5,
            fecha_caducidad=venc_proximo
        )
        # Lote B: Vence después (40 días), 10 disponibles
        lote_b = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-B-40',
            cantidad_ingresada=10,
            cantidad_disponible=10,
            fecha_caducidad=venc_lejano
        )

        # Salida por 8 unidades
        res = self.client.post('/api/inventario/salidas', {
            'material_id': self.material.id,
            'cantidad': 8,
            'motivo_destino': 'Procedimiento Quirúrgico #102'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['cantidad_total'], 8)
        self.assertEqual(len(res.data['detalles_lote']), 2)

        # Recargar lotes de la base de datos
        lote_a.refresh_from_db()
        lote_b.refresh_from_db()

        # FEFO debe haber descontado 5 de Lote A (quedando 0) y 3 de Lote B (quedando 7)
        self.assertEqual(lote_a.cantidad_disponible, 0)
        self.assertEqual(lote_b.cantidad_disponible, 7)

    def test_bloqueo_salida_mayor_a_stock_disponible(self):
        """T-208.1 y T-208.2: Rechazo total y rollback cuando la cantidad solicitada supera el stock disponible."""
        hoy = timezone.now().date()
        venc = hoy + timedelta(days=15)

        lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-SOLO-10',
            cantidad_ingresada=10,
            cantidad_disponible=10,
            fecha_caducidad=venc
        )

        # Intentar solicitar 25 unidades cuando solo hay 10
        res = self.client.post('/api/inventario/salidas', {
            'material_id': self.material.id,
            'cantidad': 25,
            'motivo_destino': 'Uso masivo'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res.data['stock_disponible_actual'], 10)
        self.assertEqual(res.data['cantidad_solicitada'], 25)
        self.assertIn('Stock insuficiente', res.data['error'])

        # Verificar que el lote mantiene sus 10 unidades intactas (rollback)
        lote.refresh_from_db()
        self.assertEqual(lote.cantidad_disponible, 10)

        # Verificar que no se creó ningún MovimientoSalida
        self.assertEqual(MovimientoSalida.objects.count(), 0)

    def test_verificacion_flag_puede_ajustar_segun_permiso(self):
        """T-208.3: Verificación del flag puede_ajustar en la respuesta de error según los permisos del usuario."""
        lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-TEST-5',
            cantidad_ingresada=5,
            cantidad_disponible=5
        )

        # 1. Probar con GestorInventario (posee ajustar_inventario) -> puede_ajustar = True
        res_gestor = self.client.post('/api/inventario/salidas', {
            'material_id': self.material.id,
            'cantidad': 10
        }, format='json')
        self.assertEqual(res_gestor.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(res_gestor.data['puede_ajustar'])

        # 2. Probar con Doctor (NO posee ajustar_inventario) -> puede_ajustar = False
        doctor_tokens = generar_tokens_para_usuario(self.doctor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {doctor_tokens["access"]}')

        res_doctor = self.client.post('/api/inventario/salidas', {
            'material_id': self.material.id,
            'cantidad': 10
        }, format='json')
        self.assertEqual(res_doctor.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res_doctor.data['puede_ajustar'])

    def test_registro_auditoria_salida_fefo(self):
        """T-207.6: Auditoría automática tras salida FEFO exitosa."""
        lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-AUD-FEFO',
            cantidad_ingresada=20,
            cantidad_disponible=20
        )

        res = self.client.post('/api/inventario/salidas', {
            'material_id': self.material.id,
            'cantidad': 5,
            'motivo_destino': 'Prueba auditoría'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        auditoria = RegistroAuditoria.objects.filter(accion='REGISTRO_SALIDA_FEFO').last()
        self.assertIsNotNone(auditoria)
        self.assertEqual(auditoria.usuario, self.gestor)
        self.assertEqual(auditoria.detalles['cantidad'], 5)
        self.assertIn('LOT-AUD-FEFO', auditoria.detalles['lotes_afectados'])

    def test_salida_con_alias_material_y_motivo(self):
        """Prueba salida enviando 'material' y 'motivo' como alias."""
        Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-ALIAS-TEST',
            cantidad_ingresada=10,
            cantidad_disponible=10
        )

        res = self.client.post('/api/inventario/salidas', {
            'material': self.material.id,
            'cantidad': 3,
            'motivo': 'Uso en consulta clínica'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['cantidad_total'], 3)

