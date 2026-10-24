from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.core.cache import cache
from apps.usuarios.models import Usuario
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.notificaciones.models import ConfiguracionSistema, CanalMensajeria
from apps.notificaciones.services import NotificationService

class NotificacionesEpica1DTestCase(TestCase):
    def setUp(self):
        cache.clear()
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        self.superadmin = Usuario.objects.create_superuser(
            username='AdminNotif',
            correo_interno='admin.notif@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.superadmin)

    def test_t112_configuracion_canal_mensajeria_api(self):
        """T-112.1 a T-112.6: GET y PATCH de canal de mensajería activo."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        # 1. Obtener configuración inicial
        res_get = self.client.get('/api/admin/config')
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)
        self.assertEqual(res_get.data['canal_mensajeria_activo'], 'TELEGRAM')

        # 2. Cambiar a WHATSAPP
        res_patch = self.client.patch('/api/admin/config/canal-mensajeria', {
            'canal_mensajeria_activo': 'WHATSAPP'
        }, format='json')
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(ConfiguracionSistema.obtener_canal_activo(), 'WHATSAPP')

        # 3. Cambiar a AMBOS
        res_ambos = self.client.patch('/api/admin/config/canal-mensajeria', {
            'canal_mensajeria_activo': 'AMBOS'
        }, format='json')
        self.assertEqual(res_ambos.status_code, status.HTTP_200_OK)
        self.assertEqual(ConfiguracionSistema.obtener_canal_activo(), 'AMBOS')

    def test_t111_service_y_fallback_silencioso(self):
        """T-111.1 a T-111.5: Despacho de notificaciones y fallback silencioso sin crash."""
        user = Usuario.objects.create_user(
            username='UserNotif',
            correo_interno='notif@clinica.com',
            password='Password123!',
            telefono='+584120001122',
            telegram_chat_id='123456789'
        )

        # Probar envío con canal TELEGRAM
        ConfiguracionSistema.objects.update_or_create(id=1, defaults={'canal_mensajeria_activo': CanalMensajeria.TELEGRAM})
        cache.clear()
        res_tel = NotificationService.enviar_mensaje(user, "Mensaje de prueba Telegram")
        self.assertTrue(res_tel)

        # Probar envío con canal WHATSAPP
        ConfiguracionSistema.objects.update_or_create(id=1, defaults={'canal_mensajeria_activo': CanalMensajeria.WHATSAPP})
        cache.clear()
        res_wa = NotificationService.enviar_mensaje(user, "Mensaje de prueba WhatsApp")
        self.assertTrue(res_wa)

        # Probar deep link
        deep_link = NotificationService.obtener_deep_link_telegram('testtoken123')
        self.assertTrue(deep_link.startswith('https://t.me/'))
        self.assertIn('testtoken123', deep_link)
