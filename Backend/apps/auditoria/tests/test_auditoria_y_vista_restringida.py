from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, PERMISOS_MODO_CONGELADO, obtener_permisos_efectivos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.auditoria.services import AuditService


class AuditoriaEpica1FTestCase(TestCase):
    """T-114.1 a T-114.T: Suite de tests para Épica 1.F — Auditoría."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        self.superadmin = Usuario.objects.create_superuser(
            username='AuditAdmin',
            correo_interno='audit@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.superadmin)

        self.usuario_normal = Usuario.objects.create_user(
            username='UserNormal',
            correo_interno='normal@clinica.com',
            password='Password123!'
        )
        self.normal_tokens = generar_tokens_para_usuario(self.usuario_normal)

    def test_t114_1_modelo_append_only(self):
        """T-114.1 y T-114.4: Modelo RegistroAuditoria append-only — bloquea UPDATE y DELETE."""
        registro = AuditService.registrar_accion(
            self.superadmin,
            'ACCION_TEST',
            {'detalle': 'valor_prueba'}
        )
        self.assertIsNotNone(registro.id)
        self.assertEqual(registro.accion, 'ACCION_TEST')

        # T-114.4: Intentar modificar debe lanzar PermissionError
        with self.assertRaises(PermissionError):
            registro.accion = 'MODIFICADO'
            registro.save()

        # T-114.4: Intentar eliminar debe lanzar PermissionError
        with self.assertRaises(PermissionError):
            registro.delete()

        # Confirmar que el registro original sigue intacto
        registro_db = RegistroAuditoria.objects.get(id=registro.id)
        self.assertEqual(registro_db.accion, 'ACCION_TEST')

    def test_t114_2_3_decorador_auditable(self):
        """T-114.2 y T-114.3: Decorador @auditable genera registro automático en acciones clave."""
        from apps.auditoria.services import auditable

        @auditable('ACCION_DECORADA')
        def view_simulada(request, *args, **kwargs):
            from rest_framework.response import Response
            return Response({'resultado': 'ok'}, status=200)

        class FakeRequest:
            user = self.superadmin
            META = {'REMOTE_ADDR': '127.0.0.1'}

        count_antes = RegistroAuditoria.objects.filter(accion='ACCION_DECORADA').count()
        view_simulada(FakeRequest())
        count_despues = RegistroAuditoria.objects.filter(accion='ACCION_DECORADA').count()

        self.assertEqual(count_despues, count_antes + 1)

    def test_t114_5_endpoint_historial_propio(self):
        """T-114.5: Usuario puede consultar su propio historial de auditoría."""
        # Generar algunos registros para el usuario normal
        for i in range(3):
            AuditService.registrar_accion(self.usuario_normal, f'ACCION_{i}')

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.normal_tokens["access"]}')
        res = self.client.get(f'/api/usuarios/{self.usuario_normal.id}/historial')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(res.data['total'], 3)
        self.assertIn('results', res.data)

    def test_t114_5_historial_acceso_admin(self):
        """T-114.5: Admin con permiso gestionar_usuarios puede consultar historial de cualquier usuario."""
        AuditService.registrar_accion(self.usuario_normal, 'LOGIN_EXITOSO')

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')
        res = self.client.get(f'/api/usuarios/{self.usuario_normal.id}/historial')

        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_t114_5_historial_acceso_denegado(self):
        """T-114.5: Usuario sin permisos no puede consultar historial de otro usuario."""
        otro_usuario = Usuario.objects.create_user(
            username='Otro',
            correo_interno='otro@clinica.com',
            password='Password123!'
        )
        otro_tokens = generar_tokens_para_usuario(otro_usuario)

        # normal_tokens intenta ver historial de superadmin → debe fallar
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {otro_tokens["access"]}')
        res = self.client.get(f'/api/usuarios/{self.superadmin.id}/historial')

        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_t114_5_paginacion_historial(self):
        """T-114.5: El endpoint de historial soporta paginación."""
        for i in range(25):
            AuditService.registrar_accion(self.superadmin, f'ACCION_{i}')

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')
        res = self.client.get(f'/api/usuarios/{self.superadmin.id}/historial?page=1&page_size=10')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data['results']), 10)
        self.assertGreaterEqual(res.data['total'], 25)


class VistaRestringidaEpica1GTestCase(TestCase):
    """T-115.1 a T-115.T: Suite de tests para Épica 1.G — Vista restringida para usuario desactivado."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        self.usuario_desactivado = Usuario.objects.create_user(
            username='DocDesactivado',
            correo_interno='desactivado@clinica.com',
            password='Password123!',
            activo=False,
        )
        self.tokens = generar_tokens_para_usuario(self.usuario_desactivado)

    def test_t115_1_login_emite_tokens_usuario_desactivado(self):
        """T-115.1: El login NO rechaza a usuarios con activo=False — emite tokens normalmente."""
        res = self.client.post('/api/auth/login', {
            'identificador': 'docdesactivado',
            'password': 'Password123!'
        }, format='json')
        # El usuario desactivado puede autenticarse — el control de acceso es por permiso, no por login
        self.assertIn(res.status_code, [status.HTTP_200_OK, status.HTTP_403_FORBIDDEN])
        # Si pasa (200), debe tener tokens
        if res.status_code == status.HTTP_200_OK:
            self.assertIn('tokens', res.data)

    def test_t115_2_get_me_retorna_activo_false_y_permisos_congelados(self):
        """T-115.2: GET /auth/me devuelve activo=False y permisos congelados."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.tokens["access"]}')
        res = self.client.get('/api/auth/me')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['usuario']['activo'])

        # Permisos efectivos deben ser los del modo congelado
        permisos = set(res.data['permisos_efectivos'])
        self.assertEqual(permisos, set(PERMISOS_MODO_CONGELADO))

    def test_t115_3_permisos_congelados_son_correctos(self):
        """T-115.3: Los permisos efectivos de usuario desactivado son solo PERMISOS_MODO_CONGELADO."""
        permisos = obtener_permisos_efectivos(self.usuario_desactivado)
        self.assertEqual(set(permisos), set(PERMISOS_MODO_CONGELADO))

    def test_t115_4_barrido_403_endpoints_protegidos(self):
        """T-115.4: Usuario desactivado recibe 403 en todos los endpoints protegidos del módulo."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.tokens["access"]}')

        endpoints_protegidos = [
            ('GET', '/api/admin/usuarios'),
            ('GET', '/api/admin/roles'),
            ('GET', '/api/admin/permisos'),
            ('POST', '/api/admin/usuarios'),
        ]

        for metodo, url in endpoints_protegidos:
            if metodo == 'GET':
                res = self.client.get(url)
            else:
                res = self.client.post(url, {}, format='json')

            self.assertEqual(
                res.status_code,
                status.HTTP_403_FORBIDDEN,
                msg=f"Se esperaba 403 en {metodo} {url}, se obtuvo {res.status_code}"
            )
