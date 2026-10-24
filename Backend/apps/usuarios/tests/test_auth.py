from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario

class AuthEpica1ATestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.raw_password = 'PasswordSegura123!'
        self.user = Usuario.objects.create_user(
            username='DoctorPerez',
            correo_interno='Doctor.Perez@clinica.com',
            password=self.raw_password,
            telefono='+59170123456'
        )
        self.admin = Usuario.objects.create_superuser(
            username='SuperAdmin',
            correo_interno='admin@clinica.com',
            password='AdminPassword123!'
        )

    def test_t101_1_to_3_creacion_y_normalizacion_usuario(self):
        """T-101.1, T-101.2, T-101.3: Modelo Usuario, campos y normalización case-insensitive."""
        self.assertEqual(self.user.username, 'doctorperez')
        self.assertEqual(self.user.correo_interno, 'doctor.perez@clinica.com')
        self.assertEqual(self.user.intentos_fallidos, 0)
        self.assertIsNone(self.user.bloqueado_hasta)
        self.assertEqual(self.user.session_version, 1)

    def test_t101_4_to_6_login_exitoso_username_y_correo(self):
        """T-101.4, T-101.5, T-101.6, T-101.10: Login por username o correo (case insensitive)."""
        # Login por username con mayúsculas
        response = self.client.post('/api/auth/login', {
            'identificador': 'DOCTORPEREZ',
            'password': self.raw_password
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('tokens', response.data)
        self.assertIn('access', response.data['tokens'])
        self.assertIn('refresh', response.data['tokens'])

        # Login por correo interno
        response_correo = self.client.post('/api/auth/login', {
            'identificador': 'Doctor.Perez@clinica.com',
            'password': self.raw_password
        }, format='json')
        self.assertEqual(response_correo.status_code, status.HTTP_200_OK)

    def test_t101_6_contrasena_case_sensitive(self):
        """T-101.6: Verificación de contraseña case-sensitive (debe rechazar contraseña con cambio de mayúsculas)."""
        response = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': 'passwordsegura123!'  # minúsculas -> incorrecto
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_t101_7_to_9_conteo_intentos_fallidos_y_bloqueo_15min(self):
        """T-101.7, T-101.8, T-101.9: Incrementar intentos fallidos y bloquear al 5to intento."""
        for i in range(4):
            res = self.client.post('/api/auth/login', {
                'identificador': 'doctorperez',
                'password': 'WrongPassword'
            }, format='json')
            self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

        self.user.refresh_from_db()
        self.assertEqual(self.user.intentos_fallidos, 4)
        self.assertFalse(self.user.esta_bloqueado())

        # 5to intento fallido -> Bloqueo
        res_5 = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': 'WrongPassword'
        }, format='json')
        self.assertEqual(res_5.status_code, status.HTTP_403_FORBIDDEN)

        self.user.refresh_from_db()
        self.assertEqual(self.user.intentos_fallidos, 5)
        self.assertTrue(self.user.esta_bloqueado())

        # Intentar login con contraseña CORRECTA durante el bloqueo -> Rechazar 403
        res_blocked = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': self.raw_password
        }, format='json')
        self.assertEqual(res_blocked.status_code, status.HTTP_403_FORBIDDEN)

    def test_t102_1_to_5_refresh_token_y_session_version(self):
        """T-102.1 a T-102.5: Endpoint refresh y validación de session_version."""
        login_res = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': self.raw_password
        }, format='json')
        refresh_token = login_res.data['tokens']['refresh']
        access_token = login_res.data['tokens']['access']

        # Solicitar nuevo access_token con el refresh_token
        refresh_res = self.client.post('/api/auth/refresh', {
            'refresh': refresh_token
        }, format='json')
        self.assertEqual(refresh_res.status_code, status.HTTP_200_OK)
        self.assertIn('access', refresh_res.data)

        # Probar endpoint protegido (/api/auth/me) con access token
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        me_res = self.client.get('/api/auth/me')
        self.assertEqual(me_res.status_code, status.HTTP_200_OK)

    def test_t104_1_to_4_cierre_sesion_remoto(self):
        """T-104.1 a T-104.4: Incrementar session_version e invalidar tokens anteriores."""
        # Obtenemos token para doctorperez
        login_res = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': self.raw_password
        }, format='json')
        access_token = login_res.data['tokens']['access']

        # Superadmin ejecuta cierre de sesión remoto sobre doctorperez
        admin_login = self.client.post('/api/auth/login', {
            'identificador': 'superadmin',
            'password': 'AdminPassword123!'
        }, format='json')
        admin_token = admin_login.data['tokens']['access']

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')
        cerrar_res = self.client.post(f'/api/admin/usuarios/{self.user.id}/cerrar-sesion')
        self.assertEqual(cerrar_res.status_code, status.HTTP_200_OK)

        self.user.refresh_from_db()
        self.assertEqual(self.user.session_version, 2)

        # Usar el access token anterior de doctorperez debe fallar con 401
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
        me_invalid_res = self.client.get('/api/auth/me')
        self.assertEqual(me_invalid_res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_perfil_usuario_patch_edicion_propia(self):
        """Test PATCH /api/auth/me para editar perfil propio y contraseña."""
        login_res = self.client.post('/api/auth/login', {
            'identificador': 'doctorperez',
            'password': self.raw_password
        }, format='json')
        access_token = login_res.data['tokens']['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')

        # 1. Editar username, nombre_completo y telefono válido de Bolivia
        patch_res = self.client.patch('/api/auth/me', {
            'username': 'dr_perez_nuevo',
            'nombre_completo': 'Dr. Juan Pérez Flores',
            'telefono': '71234567'
        }, format='json')
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_res.data['usuario']['username'], 'dr_perez_nuevo')
        self.assertEqual(patch_res.data['usuario']['nombre_completo'], 'Dr. Juan Pérez Flores')
        self.assertEqual(patch_res.data['usuario']['telefono'], '+59171234567')

        # Verificar que rechaza un username duplicado
        patch_dup = self.client.patch('/api/auth/me', {
            'username': self.admin.username
        }, format='json')
        self.assertEqual(patch_dup.status_code, status.HTTP_400_BAD_REQUEST)

        # 2. Cambiar contraseña
        nueva_pass = 'NuevaSuperPassword123!'
        cambio_pass_res = self.client.patch('/api/auth/me', {
            'password_actual': self.raw_password,
            'password_nueva': nueva_pass
        }, format='json')
        self.assertEqual(cambio_pass_res.status_code, status.HTTP_200_OK)

        # 3. Verificar que el NUEVO username y la NUEVA contraseña funcionen para login
        self.client.credentials()  # clear credentials
        relogin = self.client.post('/api/auth/login', {
            'identificador': 'dr_perez_nuevo',
            'password': nueva_pass
        }, format='json')
        self.assertEqual(relogin.status_code, status.HTTP_200_OK)

