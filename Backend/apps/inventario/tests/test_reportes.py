from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario, Rol, UsuarioRol, invalidar_cache_permisos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.auditoria.models import RegistroAuditoria
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote
from apps.inventario.models_movimientos import MovimientoSalida
from apps.inventario.models_solicitudes import SolicitudMaterial, EstadoSolicitud
from apps.inventario.models_reportes import ReporteGenerado


class ReportesPDFEpica2GTestCase(TestCase):
    """T-217.1 a T-219.3 y T-217.T: Suite de tests para Épica 2.G — Reportes en PDF (bajo demanda)."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Admin
        self.admin = Usuario.objects.create_superuser(
            username='AdminReportes',
            correo_interno='admin.reportes@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.admin)

        # Doctor
        self.doctor = Usuario.objects.create_user(
            username='DoctorReportes',
            correo_interno='doctor.reportes@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)
        invalidar_cache_permisos(self.doctor)

        # Datos de inventario
        self.area = Area.objects.create(nombre='Cirugía')
        self.categoria = CategoriaMaterial.objects.create(nombre='Consumibles')
        self.material = Material.objects.create(
            nombre='Gasa Estéril',
            area=self.area,
            categoria=self.categoria,
            stock_minimo=5
        )

        # Lote ingresado
        self.lote = Lote.objects.create(
            material=self.material,
            codigo_lote='LOT-GAS-01',
            cantidad_ingresada=100,
            cantidad_disponible=80,
            usuario_ingreso=self.doctor
        )

        # Movimiento de salida
        self.salida = MovimientoSalida.objects.create(
            material=self.material,
            cantidad_total=20,
            motivo_destino='Procedimiento en Quirófano',
            usuario=self.doctor
        )

        # Solicitud de material
        self.solicitud = SolicitudMaterial.objects.create(
            solicitante=self.doctor,
            material=self.material,
            cantidad_solicitada=15,
            estado=EstadoSolicitud.PENDIENTE
        )

    def test_generar_pdf_reporte_inventario_por_rango_fechas(self):
        """T-217.1 a T-217.4: Endpoint POST /inventario/reportes/pdf retorna archivo PDF válido."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        f_ini = (timezone.now() - timedelta(days=7)).strftime('%Y-%m-%d')
        f_fin = timezone.now().strftime('%Y-%m-%d')

        res = self.client.post('/api/inventario/reportes/pdf', {
            'fecha_inicio': f_ini,
            'fecha_fin': f_fin
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertTrue(res['Content-Disposition'].startswith('attachment; filename="reporte_inventario_'))
        self.assertTrue(res.content.startswith(b'%PDF'))

    def test_reporte_filtrado_por_usuario_especifico(self):
        """T-218.1 a T-218.3: Filtrar reporte por usuario_id específico (Doctor)."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        res = self.client.post('/api/inventario/reportes/pdf', {
            'usuario_id': self.doctor.id
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertTrue(res.content.startswith(b'%PDF'))

    def test_entrega_dual_descarga_y_mensajeria(self):
        """T-219.1 a T-219.3: Opción enviar_mensajeria=True despacha la notificación y retorna PDF."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        res = self.client.post('/api/inventario/reportes/pdf', {
            'enviar_mensajeria': True
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertTrue(res.content.startswith(b'%PDF'))

        # Verificar auditoría de envío por mensajería
        auditoria_envio = RegistroAuditoria.objects.filter(accion='ENVIO_REPORTE_MENSAJERIA')
        self.assertTrue(auditoria_envio.exists())

    def test_endpoint_enviar_reporte_por_mensajeria_directo(self):
        """T-219.2: Endpoint dedicado POST /inventario/reportes/enviar-por-mensajeria."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        res = self.client.post('/api/inventario/reportes/enviar-por-mensajeria', {}, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('mensaje', res.data)
        self.assertIn('resumen', res.data)
        self.assertEqual(res.data['resumen']['total_ingresos'], 1)

    def test_auditoria_generacion_reporte(self):
        """T-217.5: Se registra acción GENERACION_REPORTE_PDF en la bitácora de auditoría."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        self.client.post('/api/inventario/reportes/pdf', {}, format='json')

        auditoria = RegistroAuditoria.objects.filter(accion='GENERACION_REPORTE_PDF')
        self.assertTrue(auditoria.exists())
        self.assertEqual(auditoria.first().usuario, self.admin)

    def test_historial_reportes_se_registra_al_generar_pdf(self):
        """T-REPORTE-HIST.1 y T-REPORTE-HIST.4: Al generar un PDF se persiste la fila en ReporteGenerado."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        res = self.client.post('/api/inventario/reportes/pdf', {
            'area_id': self.area.id,
            'categoria_id': self.categoria.id,
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Verificar que se creó el registro con los parámetros correspondientes
        ultimo_reporte = ReporteGenerado.objects.order_by('-generado_en').first()
        self.assertIsNotNone(ultimo_reporte)
        self.assertEqual(ultimo_reporte.generado_por, self.admin)
        self.assertEqual(ultimo_reporte.area, self.area)
        self.assertEqual(ultimo_reporte.categoria, self.categoria)
        self.assertFalse(ultimo_reporte.enviado_por_mensajeria)
        self.assertIn('area_id', ultimo_reporte.parametros_regeneracion)
        self.assertEqual(ultimo_reporte.parametros_regeneracion['area_id'], self.area.id)

    def test_historial_reportes_endpoint_get(self):
        """T-REPORTE-HIST.2: GET /api/inventario/reportes/historial retorna la lista de reportes."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

        # Generar un reporte primero
        self.client.post('/api/inventario/reportes/pdf', {}, format='json')

        res = self.client.get('/api/inventario/reportes/historial')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('reportes', res.data)
        self.assertGreaterEqual(res.data['total'], 1)

        primer_item = res.data['reportes'][0]
        self.assertIn('id', primer_item)
        self.assertIn('generado_por_nombre', primer_item)
        self.assertIn('parametros_regeneracion', primer_item)
        self.assertIn('enviado_por_mensajeria', primer_item)

    def test_historial_reportes_permisos_usuario_no_admin(self):
        """T-REPORTE-HIST.2: Usuario regular solo visualiza sus propios reportes."""
        # El admin genera un reporte
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')
        self.client.post('/api/inventario/reportes/pdf', {}, format='json')

        # El doctor consulta el historial (no es admin ni superadmin)
        doctor_tokens = generar_tokens_para_usuario(self.doctor)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {doctor_tokens["access"]}')

        res = self.client.get('/api/inventario/reportes/historial')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        # El doctor no generó ninguno, por tanto debe ver 0
        self.assertEqual(len(res.data['reportes']), 0)

