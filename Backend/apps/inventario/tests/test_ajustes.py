from django.test import TestCase
from django.core.exceptions import ValidationError
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, UsuarioRol
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.models_ajustes import AjusteInventario


class AjustesInventarioEpica2DTestCase(TestCase):
    """T-209.1 a T-210.3 y T-209.T: Suite de tests para Épica 2.D — Ajustes de Inventario."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Usuario GestorInventario (posee ajustar_inventario)
        self.gestor = Usuario.objects.create_user(
            username='GestorAjustes',
            correo_interno='gestorajustes@clinica.com',
            password='Password123!'
        )
        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.gestor, rol=rol_gestor)

        # Usuario Doctor (NO posee ajustar_inventario)
        self.doctor = Usuario.objects.create_user(
            username='DoctorAjustes',
            correo_interno='doctorajustes@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)

        # Autenticar como Gestor por defecto
        self.gestor_tokens = generar_tokens_para_usuario(self.gestor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')

        # Área, categoría, material y lote inicial
        self.area = Area.objects.create(nombre='Odontología')
        self.categoria = CategoriaMaterial.objects.create(nombre='Consumibles Odontológicos')
        self.material = Material.objects.create(
            nombre='Resina Compuesta A2',
            area=self.area,
            categoria=self.categoria,
            unidad_medida='jeringa'
        )
        self.lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-RES-01',
            cantidad_ingresada=10,
            cantidad_disponible=10
        )

    def test_creacion_ajuste_y_actualizacion_lote(self):
        """T-209.1 a T-209.3: Registro de ajuste manual actualiza stock del lote y crea AjusteInventario."""
        res = self.client.post('/api/inventario/ajustes', {
            'lote_id': self.lote.id,
            'cantidad_nueva': 25,
            'motivo': 'Conteo físico anual de inventario en farmacia central'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['cantidad_anterior'], 10)
        self.assertEqual(res.data['cantidad_nueva'], 25)
        self.assertEqual(res.data['lote_codigo'], 'LOT-RES-01')

        # Verificar actualización del lote
        self.lote.refresh_from_db()
        self.assertEqual(self.lote.cantidad_disponible, 25)

        # Verificar registro de ajuste en la base de datos
        ajuste = AjusteInventario.objects.get(id=res.data['id'])
        self.assertEqual(ajuste.lote, self.lote)
        self.assertEqual(ajuste.usuario, self.gestor)
        self.assertEqual(ajuste.cantidad_anterior, 10)
        self.assertEqual(ajuste.cantidad_nueva, 25)

    def test_rechazo_motivo_vacio_y_cantidad_negativa(self):
        """T-209.4: Validación de motivo obligatorio y cantidad no negativa."""
        # 1. Motivo vacío
        res_vacio = self.client.post('/api/inventario/ajustes', {
            'lote_id': self.lote.id,
            'cantidad_nueva': 5,
            'motivo': '   '
        }, format='json')
        self.assertEqual(res_vacio.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Cantidad negativa
        res_negativo = self.client.post('/api/inventario/ajustes', {
            'lote_id': self.lote.id,
            'cantidad_nueva': -3,
            'motivo': 'Motivo válido'
        }, format='json')
        self.assertEqual(res_negativo.status_code, status.HTTP_400_BAD_REQUEST)

    def test_inmutabilidad_modelo_ajuste(self):
        """T-210.3: Inmutabilidad — No se puede editar ni borrar un registro de AjusteInventario."""
        ajuste = AjusteInventario.objects.create(
            lote=self.lote,
            usuario=self.gestor,
            cantidad_anterior=10,
            cantidad_nueva=15,
            motivo='Ajuste inicial'
        )

        # Intentar modificar y guardar
        ajuste.motivo = 'Motivo cambiado'
        with self.assertRaises(ValidationError):
            ajuste.save()

        # Intentar eliminar
        with self.assertRaises(ValidationError):
            ajuste.delete()

    def test_permisos_y_auditoria_ajuste(self):
        """T-209.2 y T-209.5: Bloqueo por falta de permiso 'ajustar_inventario' y registro en auditoría."""
        # 1. Intentar con Doctor
        doctor_tokens = generar_tokens_para_usuario(self.doctor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {doctor_tokens["access"]}')

        res_doctor = self.client.post('/api/inventario/ajustes', {
            'lote_id': self.lote.id,
            'cantidad_nueva': 8,
            'motivo': 'Intento por doctor'
        }, format='json')
        self.assertEqual(res_doctor.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Reintentar con Gestor y verificar auditoría
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')
        res_gestor = self.client.post('/api/inventario/ajustes', {
            'lote_id': self.lote.id,
            'cantidad_nueva': 8,
            'motivo': 'Ajuste por mermas'
        }, format='json')
        self.assertEqual(res_gestor.status_code, status.HTTP_201_CREATED)

        auditoria = RegistroAuditoria.objects.filter(accion='AJUSTE_INVENTARIO').last()
        self.assertIsNotNone(auditoria)
        self.assertEqual(auditoria.usuario, self.gestor)
        self.assertEqual(auditoria.detalles['cantidad_anterior'], 10)
        self.assertEqual(auditoria.detalles['cantidad_nueva'], 8)

    def test_historial_ajustes_con_filtros(self):
        """T-210.1 y T-210.2: Consulta de historial independiente de ajustes con filtros por lote y material."""
        AjusteInventario.objects.create(
            lote=self.lote,
            usuario=self.gestor,
            cantidad_anterior=10,
            cantidad_nueva=12,
            motivo='Ajuste 1'
        )

        res = self.client.get('/api/inventario/ajustes')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(res.data), 1)

        # Filtro por lote_id
        res_lote = self.client.get(f'/api/inventario/ajustes?lote_id={self.lote.id}')
        self.assertEqual(res_lote.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_lote.data), 1)

        # Filtro por material_id
        res_mat = self.client.get(f'/api/inventario/ajustes?material_id={self.material.id}')
        self.assertEqual(res_mat.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_mat.data), 1)

    def test_ajuste_con_alias_lote(self):
        """Prueba que el ajuste acepte el campo 'lote' como alias de 'lote_id'."""
        self.client.force_authenticate(user=self.gestor)
        res = self.client.post('/api/inventario/ajustes', {
            'lote': self.lote.id,
            'cantidad_nueva': 15,
            'motivo': 'Ajuste vía alias lote'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.lote.refresh_from_db()
        self.assertEqual(self.lote.cantidad_disponible, 15)

    def test_ajuste_directo_por_material_id(self):
        """Prueba ajuste directo especificando material_id cuando no se envía lote_id."""
        self.client.force_authenticate(user=self.gestor)
        res = self.client.post('/api/inventario/ajustes', {
            'material_id': self.material.id,
            'cantidad_nueva': 25,
            'motivo': 'Ajuste directo por material'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(self.material.stock_total_disponible(), 25)

    def test_historial_movimientos_unificados(self):
        """Consulta el historial cronológico unificado de movimientos de un material."""
        from apps.inventario.models_movimientos import MovimientoSalida, MovimientoSalidaLote
        self.client.force_authenticate(user=self.gestor)

        # Crear una salida
        salida = MovimientoSalida.objects.create(
            material=self.material,
            cantidad_total=3,
            motivo_destino='Uso en quirofano',
            usuario=self.gestor
        )
        MovimientoSalidaLote.objects.create(
            movimiento_salida=salida,
            lote=self.lote,
            cantidad_descontada=3
        )

        # Crear un ajuste
        AjusteInventario.objects.create(
            lote=self.lote,
            usuario=self.gestor,
            cantidad_anterior=10,
            cantidad_nueva=14,
            motivo='Conteo físico'
        )

        res = self.client.get(f'/api/inventario/materiales/{self.material.id}/movimientos')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        tipos = [m['tipo'] for m in res.data]
        self.assertIn('entrada', tipos)
        self.assertIn('salida', tipos)
        self.assertIn('ajuste', tipos)

