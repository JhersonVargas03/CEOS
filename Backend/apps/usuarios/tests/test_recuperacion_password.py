from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.core.cache import cache
from apps.usuarios.models import Usuario, CodigoRecuperacion
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.auditoria.models import RegistroAuditoria

class RecuperacionPasswordEpica1ETestCase(TestCase):
    def setUp(self):
        cache.clear()
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        self.user = Usuario.objects.create_user(
            username='UsuarioRecuperar',
            correo_interno='recuperar@clinica.com',
            password='PasswordVieja123!',
            telefono='+59179990000',
            telegram_chat_id='998877'
        )

    def test_t113_solicitud_anti_enumeracion_y_rate_limiting(self):
        """T-113.1 a T-113.5: Solicitud con respuesta constante anti-enumeración y rate limiting."""
        # 1. Solicitar para usuario existente
        res_existente = self.client.post('/api/auth/recuperar/solicitar', {
            'identificador': 'UsuarioRecuperar'
        }, format='json')
        self.assertEqual(res_existente.status_code, status.HTTP_200_OK)

        # 2. Solicitar para usuario inexistente -> Mismo mensaje y 200 OK
        res_inexistente = self.client.post('/api/auth/recuperar/solicitar', {
            'identificador': 'UsuarioInventado'
        }, format='json')
        self.assertEqual(res_inexistente.status_code, status.HTTP_200_OK)
        self.assertEqual(res_existente.data['mensaje'], res_inexistente.data['mensaje'])

        # 3. Rate Limit check: Segunda solicitud inmediata para el mismo usuario -> 429
        res_rate = self.client.post('/api/auth/recuperar/solicitar', {
            'identificador': 'recuperar@clinica.com'
        }, format='json')
        self.assertEqual(res_rate.status_code, status.HTTP_429_TOO_MANY_REQUESTS)

    def test_t113_verificacion_codigo_y_limite_intentos_fallidos(self):
        """T-113.6 a T-113.7: Validación de códigos y bloqueo tras 3 intentos erróneos."""
        # Generar código directamente
        self.client.post('/api/auth/recuperar/solicitar', {'identificador': 'UsuarioRecuperar'}, format='json')
        cod_obj = CodigoRecuperacion.objects.filter(usuario=self.user, usado=False).first()
        self.assertIsNotNone(cod_obj)

        # 3 intentos fallidos con código erróneo
        for i in range(3):
            res_fail = self.client.post('/api/auth/recuperar/verificar', {
                'identificador': 'UsuarioRecuperar',
                'codigo': '000000'
            }, format='json')
            self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)

        cod_obj.refresh_from_db()
        self.assertTrue(cod_obj.usado)  # Se auto-invalida tras 3 intentos

    def test_t113_flujo_completo_recuperacion_y_nueva_password(self):
        """T-113.8 a T-113.10: Cambio exitoso de clave, invalidación de código y auditoría."""
        # 1. Solicitar
        self.client.post('/api/auth/recuperar/solicitar', {'identificador': 'UsuarioRecuperar'}, format='json')
        cod_obj = CodigoRecuperacion.objects.filter(usuario=self.user, usado=False).first()
        codigo_valido = cod_obj.codigo

        # 2. Verificar código
        res_verif = self.client.post('/api/auth/recuperar/verificar', {
            'identificador': 'UsuarioRecuperar',
            'codigo': codigo_valido
        }, format='json')
        self.assertEqual(res_verif.status_code, status.HTTP_200_OK)

        # 3. Establecer nueva contraseña
        res_nueva = self.client.post('/api/auth/recuperar/nueva-contrasena', {
            'identificador': 'UsuarioRecuperar',
            'codigo': codigo_valido,
            'nueva_password': 'ClaveSuperSegura2026!'
        }, format='json')
        self.assertEqual(res_nueva.status_code, status.HTTP_200_OK)

        # Verificar que la clave cambió y el código quedó usado
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('ClaveSuperSegura2026!'))
        cod_obj.refresh_from_db()
        self.assertTrue(cod_obj.usado)

        # Verificar auditoría
        self.assertTrue(RegistroAuditoria.objects.filter(accion='CAMBIO_PASSWORD_RECUPERACION').exists())
