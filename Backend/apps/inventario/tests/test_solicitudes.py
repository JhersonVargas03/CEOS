from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, UsuarioRol, invalidar_cache_permisos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.notificaciones.models import NotificacionApp
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.models_solicitudes import SolicitudMaterial


class SolicitudesMaterialEpica2ETestCase(TestCase):
    """T-211.1 a T-214.3 y T-211.T: Suite de tests para Épica 2.E — Solicitudes de Material."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Doctor (solicitante)
        self.doctor = Usuario.objects.create_user(
            username='DoctorSolicitante',
            correo_interno='doctor@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)
        invalidar_cache_permisos(self.doctor)

        # Gestor (aprobador)
        self.gestor = Usuario.objects.create_user(
            username='GestorInventarioApp',
            correo_interno='gestor@clinica.com',
            password='Password123!'
        )
        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.gestor, rol=rol_gestor)
        invalidar_cache_permisos(self.gestor)

        # Tokens
        self.doctor_tokens = generar_tokens_para_usuario(self.doctor)
        self.gestor_tokens = generar_tokens_para_usuario(self.gestor)

        # Material y Lote
        self.area = Area.objects.create(nombre='Cirugía')
        self.categoria = CategoriaMaterial.objects.create(nombre='Instrumental')
        self.material = Material.objects.create(
            nombre='Bisturí Estéril N°15',
            area=self.area,
            categoria=self.categoria,
            unidad_medida='caja'
        )
        self.lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-BIS-01',
            cantidad_ingresada=50,
            cantidad_disponible=50
        )

        # Autenticar Doctor por defecto
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.doctor_tokens["access"]}')

    def test_creacion_solicitud_material(self):
        """T-211.1 a T-211.6: Creación de solicitud en estado pendiente, motivo sin_stock por defecto y notificación al gestor."""
        res = self.client.post('/api/inventario/solicitudes', {
            'material_id': self.material.id,
            'cantidad_solicitada': 5,
            'motivo': ''
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['estado'], 'pendiente')
        self.assertEqual(res.data['motivo'], 'sin_stock')
        self.assertEqual(res.data['cantidad_solicitada'], 5)

        # Verificar NotificacionApp enviada al gestor
        notif = NotificacionApp.objects.filter(usuario=self.gestor).last()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.tipo, 'solicitud_creada')

        # Verificar auditoría
        auditoria = RegistroAuditoria.objects.filter(accion='CREACION_SOLICITUD_MATERIAL').last()
        self.assertIsNotNone(auditoria)

    def test_edicion_y_cancelacion_solicitud_propia(self):
        """T-212.1 a T-212.4: Edición y cancelación de solicitud propia en estado pendiente."""
        solicitud = SolicitudMaterial.objects.create(
            solicitante=self.doctor,
            material=self.material,
            cantidad_solicitada=10,
            motivo='Reposición preventiva',
            estado='pendiente'
        )

        # 1. Edición parcial
        res_edit = self.client.patch(f'/api/inventario/solicitudes/{solicitud.id}', {
            'cantidad_solicitada': 15
        }, format='json')
        self.assertEqual(res_edit.status_code, status.HTTP_200_OK)
        self.assertEqual(res_edit.data['cantidad_solicitada'], 15)

        # 2. Cancelación
        res_cancel = self.client.post(f'/api/inventario/solicitudes/{solicitud.id}/cancelar')
        self.assertEqual(res_cancel.status_code, status.HTTP_200_OK)
        self.assertEqual(res_cancel.data['estado'], 'cancelada')

        # 3. Intentar editar solicitud cancelada debe fallar
        res_edit_fail = self.client.patch(f'/api/inventario/solicitudes/{solicitud.id}', {
            'cantidad_solicitada': 20
        }, format='json')
        self.assertEqual(res_edit_fail.status_code, status.HTTP_400_BAD_REQUEST)

    def test_resolucion_solicitud_aprobada_y_notificacion(self):
        """T-213.2, T-213.4 y T-213.5: Aprobar solicitud no altera el stock del lote y notifica al solicitante."""
        solicitud = SolicitudMaterial.objects.create(
            solicitante=self.doctor,
            material=self.material,
            cantidad_solicitada=5,
            motivo='Stock agotado en pabellón A',
            estado='pendiente'
        )

        # Autenticar como Gestor
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')

        res_resolver = self.client.post(f'/api/inventario/solicitudes/{solicitud.id}/resolver', {
            'accion': 'aprobar',
            'comentario': 'Solicitud aprobada para retiro inmediato en farmacia central'
        }, format='json')

        self.assertEqual(res_resolver.status_code, status.HTTP_200_OK)
        self.assertEqual(res_resolver.data['estado'], 'aprobada')

        # T-213.4: Verificar que el stock NO fue alterado automáticamente
        self.lote.refresh_from_db()
        self.assertEqual(self.lote.cantidad_disponible, 50)

        # T-213.5: Notificación in-app al Doctor
        notif_doctor = NotificacionApp.objects.filter(usuario=self.doctor).last()
        self.assertIsNotNone(notif_doctor)
        self.assertEqual(notif_doctor.tipo, 'solicitud_resuelta')

    def test_resolucion_solicitud_rechazada_comentario_obligatorio(self):
        """T-213.3: Rechazo de solicitud exige comentario obligatorio."""
        solicitud = SolicitudMaterial.objects.create(
            solicitante=self.doctor,
            material=self.material,
            cantidad_solicitada=10,
            estado='pendiente'
        )

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')

        # Intentar rechazar sin comentario
        res_sin_comentario = self.client.post(f'/api/inventario/solicitudes/{solicitud.id}/resolver', {
            'accion': 'rechazar',
            'comentario': '   '
        }, format='json')
        self.assertEqual(res_sin_comentario.status_code, status.HTTP_400_BAD_REQUEST)

        # Rechazar con comentario válido
        res_con_comentario = self.client.post(f'/api/inventario/solicitudes/{solicitud.id}/resolver', {
            'accion': 'rechazar',
            'comentario': 'Se dispone de alternativa equivalente en stock'
        }, format='json')
        self.assertEqual(res_con_comentario.status_code, status.HTTP_200_OK)
        self.assertEqual(res_con_comentario.data['estado'], 'rechazada')

    def test_vista_global_y_filtros(self):
        """T-214.1 y T-214.2: Vista global para Gestores/Admins y propia para Doctores."""
        solicitud = SolicitudMaterial.objects.create(
            solicitante=self.doctor,
            material=self.material,
            cantidad_solicitada=3,
            estado='pendiente'
        )

        # Doctor ve 1 solicitud
        res_doctor = self.client.get('/api/inventario/solicitudes')
        self.assertEqual(res_doctor.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_doctor.data), 1)

        # Gestor ve todas y filtra por estado=pendiente
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.gestor_tokens["access"]}')
        res_gestor = self.client.get('/api/inventario/solicitudes?estado=pendiente')
        self.assertEqual(res_gestor.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_gestor.data), 1)

    def test_solicitar_nuevo_material_no_catalogado(self):
        """Permite solicitar un nuevo material no existente en inventario con nombre y área."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.doctor_tokens["access"]}')

        res = self.client.post('/api/inventario/solicitudes', {
            'nombre_material_nuevo': 'Resina Compuesta Fotocurable A2',
            'area_id': self.area.id,
            'unidad_medida': 'tubo',
            'cantidad_solicitada': 4,
            'motivo': 'Nuevo tratamiento odontológico restaurador'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['nombre_material_nuevo'], 'Resina Compuesta Fotocurable A2')
        self.assertEqual(res.data['material_nombre'], 'Resina Compuesta Fotocurable A2')
        self.assertEqual(res.data['area_nombre'], self.area.nombre)
        self.assertEqual(res.data['cantidad_solicitada'], 4)
        self.assertEqual(res.data['estado'], 'pendiente')
        self.assertIsNone(res.data['material'])

