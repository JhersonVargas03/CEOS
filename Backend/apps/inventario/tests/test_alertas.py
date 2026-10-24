from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, UsuarioRol, invalidar_cache_permisos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.notificaciones.models import ConfiguracionSistema, NotificacionApp
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.tasks import (
    materiales_bajo_minimo,
    lotes_con_alerta_vencimiento_activa,
    revisar_alertas_inventario
)


class AlertasInventarioEpica2FTestCase(TestCase):
    """T-215.1 a T-216.4 y T-215.T: Suite de tests para Épica 2.F — Alertas de Stock Bajo y Vencimiento."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Admin
        self.admin = Usuario.objects.create_superuser(
            username='AdminAlertas',
            correo_interno='admin.alertas@clinica.com',
            password='Password123!'
        )

        # Gestor de inventario
        self.gestor = Usuario.objects.create_user(
            username='GestorAlertas',
            correo_interno='gestor.alertas@clinica.com',
            password='Password123!'
        )
        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        UsuarioRol.objects.create(usuario=self.gestor, rol=rol_gestor)
        invalidar_cache_permisos(self.gestor)

        self.admin_tokens = generar_tokens_para_usuario(self.admin)

        # Datos de inventario
        self.area = Area.objects.create(nombre='Farmacia Central')
        self.categoria = CategoriaMaterial.objects.create(nombre='Medicamentos')

        # Material 1: Bajo mínimo (Stock 0, Mínimo 10)
        self.mat_bajo_stock = Material.objects.create(
            nombre='Amoxicilina 500mg',
            area=self.area,
            categoria=self.categoria,
            stock_minimo=10
        )

        # Material 2: Con stock normal (Stock 50, Mínimo 10)
        self.mat_ok = Material.objects.create(
            nombre='Paracetamol 500mg',
            area=self.area,
            categoria=self.categoria,
            stock_minimo=10
        )
        self.lote_ok = Lote.objects.create(
            material=self.mat_ok,
            codigo_lote='LOT-PARA-01',
            cantidad_ingresada=50,
            cantidad_disponible=50,
            fecha_caducidad=timezone.now().date() + timedelta(days=120)
        )

        # Material 3: Lote próximo a vencer (10 días restantes)
        self.mat_vencer = Material.objects.create(
            nombre='Insulina NPH',
            area=self.area,
            categoria=self.categoria,
            stock_minimo=2
        )
        self.lote_vencer = Lote.objects.create(
            material=self.mat_vencer,
            codigo_lote='LOT-INS-99',
            cantidad_ingresada=10,
            cantidad_disponible=10,
            fecha_caducidad=timezone.now().date() + timedelta(days=10)
        )

    def test_materiales_bajo_minimo_y_lotes_vencimiento_helpers(self):
        """T-215.2 & T-215.3: Detección correcta de materiales bajo mínimo y lotes próximos a vencer."""
        bajo_minimo = materiales_bajo_minimo()
        # Debe incluir mat_bajo_stock (0 <= 10)
        materiales_ids = [m[0].id for m in bajo_minimo]
        self.assertIn(self.mat_bajo_stock.id, materiales_ids)
        self.assertNotIn(self.mat_ok.id, materiales_ids)

        lotes_alerta = lotes_con_alerta_vencimiento_activa()
        lotes_ids = [l[0].id for l in lotes_alerta]
        self.assertIn(self.lote_vencer.id, lotes_ids)
        self.assertNotIn(self.lote_ok.id, lotes_ids)

    def test_ejecucion_revisar_alertas_envia_notificaciones(self):
        """T-215.1, T-215.4 y T-215.5: Ejecución del job envía notificaciones in-app a gestores y admins."""
        res = revisar_alertas_inventario()
        self.assertEqual(res['status'], 'completado')
        self.assertGreaterEqual(res['alertas_enviadas'], 2)

        # Verificar NotificacionApp creadas para el gestor
        notifs_gestor = NotificacionApp.objects.filter(usuario=self.gestor)
        self.assertTrue(notifs_gestor.filter(tipo='alerta_stock_bajo').exists())
        self.assertTrue(notifs_gestor.filter(tipo='alerta_vencimiento').exists())

    def test_evitar_notificaciones_duplicadas_mismo_dia(self):
        """T-215.6: La reejecución en la misma fecha no genera notificaciones duplicadas."""
        # Primera ejecución
        revisar_alertas_inventario()
        count_primera = NotificacionApp.objects.count()

        # Segunda ejecución inmediata
        res_segunda = revisar_alertas_inventario()
        count_segunda = NotificacionApp.objects.count()

        self.assertEqual(count_primera, count_segunda)
        self.assertEqual(res_segunda['alertas_enviadas'], 0)

    def test_toggle_alertas_desactivadas(self):
        """T-216.3: Respetar toggle de alertas desactivadas en ConfiguracionSistema."""
        config = ConfiguracionSistema.objects.first()
        if not config:
            config = ConfiguracionSistema.objects.create(alertas_inventario_activas=False)
        else:
            config.alertas_inventario_activas = False
            config.save()

        res = revisar_alertas_inventario()
        self.assertEqual(res['status'], 'desactivado')
        self.assertEqual(res['alertas_enviadas'], 0)
        self.assertEqual(NotificacionApp.objects.count(), 0)

    def test_endpoint_toggle_alertas_inventario(self):
        """T-216.2: Admin altera el toggle de alertas vía PATCH /admin/config/alertas-inventario."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        res = self.client.patch('/api/admin/config/alertas-inventario', {
            'alertas_inventario_activas': False
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['configuracion']['alertas_inventario_activas'])
        self.assertFalse(ConfiguracionSistema.obtener_alertas_inventario_activas())
