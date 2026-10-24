from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.core.cache import cache
from apps.usuarios.models import Usuario, Rol, obtener_permisos_efectivos, PERMISOS_MODO_CONGELADO
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria

class GestionCuentasEpica1CTestCase(TestCase):
    def setUp(self):
        cache.clear()
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        self.superadmin = Usuario.objects.create_superuser(
            username='AdminBoss',
            correo_interno='boss@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.superadmin)

    def test_t108_creacion_cuenta_y_password_temporal(self):
        """T-108.1 a T-108.6: Creación de cuenta por Admin con contraseña temporal."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        rol_doctor = Rol.objects.get(nombre='Doctor')
        res = self.client.post('/api/admin/usuarios', {
            'username': 'NuevoDoctor',
            'correo_interno': 'nuevo.doc@clinica.com',
            'telefono': '+59174205205',
            'roles_ids': [rol_doctor.id]
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn('password_temporal', res.data)
        self.assertFalse(res.data['usuario']['primer_login_completado'])

        # Verificar registro en auditoría
        self.assertTrue(RegistroAuditoria.objects.filter(accion='CREACION_USUARIO').exists())

    def test_t109_flujo_primer_login_y_middleware_bloqueo(self):
        """T-109.1 a T-109.8: Middleware de bloqueo y flujo obligatorio de primer login."""
        # 1. Crear usuario nuevo en primer login
        user = Usuario.objects.create_user(
            username='DocPrimerLogin',
            correo_interno='doc1@clinica.com',
            password='TempPassword123!',
            telefono='+59172345678',
            primer_login_completado=False
        )
        rol_sa = Rol.objects.get(es_superadmin=True)
        user.roles.add(rol_sa)
        user_tokens = generar_tokens_para_usuario(user)

        # 2. Intentar acceder a endpoint operativo (ej. /api/admin/roles) -> Debe ser bloqueado con 403 por Middleware
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {user_tokens["access"]}')
        res_bloqueado = self.client.get('/api/admin/roles')
        self.assertEqual(res_bloqueado.status_code, status.HTTP_403_FORBIDDEN)
        import json
        data_bloqueado = res_bloqueado.data if hasattr(res_bloqueado, 'data') else json.loads(res_bloqueado.content)
        self.assertIn('primer_login_completado', data_bloqueado)

        # 3. Paso 1: Cambiar contraseña
        res_pass = self.client.post('/api/auth/primer-login/cambiar-password', {
            'password_actual': 'TempPassword123!',
            'password_nueva': 'NuevaClaveSegura123!'
        }, format='json')
        self.assertEqual(res_pass.status_code, status.HTTP_200_OK)

        # 4. Paso 2: Vincular Telegram
        res_tg = self.client.post('/api/auth/primer-login/vincular-telegram')
        self.assertEqual(res_tg.status_code, status.HTTP_200_OK)
        token_tg = res_tg.data['telegram_token']

        # Simular Webhook de Telegram
        res_webhook = self.client.post('/api/telegram/webhook', {
            'message': {
                'chat': {'id': 987654321},
                'text': f'/start {token_tg}'
            }
        }, format='json')
        self.assertEqual(res_webhook.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertTrue(user.telegram_vinculado)

        # 5. Paso 3: Verificar teléfono OTP
        res_otp_send = self.client.post('/api/auth/primer-login/enviar-otp-telefono')
        self.assertEqual(res_otp_send.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        otp_codigo = user.otp_telefono_codigo

        res_otp_conf = self.client.post('/api/auth/primer-login/confirmar-telefono', {
            'otp': otp_codigo
        }, format='json')
        self.assertEqual(res_otp_conf.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertTrue(user.telefono_verificado)

        # 6. Finalizar primer login
        res_fin = self.client.post('/api/auth/primer-login/finalizar')
        self.assertEqual(res_fin.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertTrue(user.primer_login_completado)

        # Confirmar registro en auditoría
        self.assertTrue(RegistroAuditoria.objects.filter(accion='PRIMER_LOGIN_FINALIZADO').exists())

    def test_t110_edicion_desactivacion_reactivacion_cuenta(self):
        """T-110.1 a T-110.5: Edición, desactivación y reactivación de cuenta con auditoría."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        target = Usuario.objects.create_user(
            username='UsuarioPrueba',
            correo_interno='prueba@clinica.com',
            password='Password123!'
        )

        # 1. Editar datos
        res_edit = self.client.patch(f'/api/admin/usuarios/{target.id}', {
            'telefono': '+59173456789'
        }, format='json')
        self.assertEqual(res_edit.status_code, status.HTTP_200_OK)

        # 2. Desactivar usuario
        res_desact = self.client.patch(f'/api/admin/usuarios/{target.id}/estado', {
            'activo': False
        }, format='json')
        self.assertEqual(res_desact.status_code, status.HTTP_200_OK)
        target.refresh_from_db()
        self.assertFalse(target.activo)
        self.assertEqual(set(obtener_permisos_efectivos(target)), set(PERMISOS_MODO_CONGELADO))

        # 3. Reactivar usuario
        res_react = self.client.patch(f'/api/admin/usuarios/{target.id}/estado', {
            'activo': True
        }, format='json')
        self.assertEqual(res_react.status_code, status.HTTP_200_OK)
        target.refresh_from_db()
        self.assertTrue(target.activo)

        # Confirmar auditoría
        self.assertTrue(RegistroAuditoria.objects.filter(accion='DESACTIVACION_CUENTA').exists())
        self.assertTrue(RegistroAuditoria.objects.filter(accion='REACTIVACION_CUENTA').exists())
