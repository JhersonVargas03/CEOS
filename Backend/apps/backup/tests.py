import os
from unittest.mock import patch
from rest_framework.test import APITestCase
from rest_framework import status

from apps.usuarios.models import Usuario, Rol, UsuarioRol, invalidar_cache_permisos
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from .models import RegistroBackup
from .services import ejecutar_backup


class BackupEpica3ATestCase(APITestCase):
    """
    Suite de pruebas automatizadas para la Épica 3.A — Backup Automático y Manual (HU-301, HU-302, HU-303).
    """

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.superadmin = Usuario.objects.create_superuser(
            username='superadmin_backup',
            correo_interno='superadmin@clinica.com',
            password='Password123!'
        )
        self.doctor = Usuario.objects.create_user(
            username='doctor_backup',
            correo_interno='doctor@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)
        invalidar_cache_permisos(self.doctor)

        tokens_sa = generar_tokens_para_usuario(self.superadmin)
        self.sa_client = self.client_class()
        self.sa_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens_sa['access']}")

        tokens_doc = generar_tokens_para_usuario(self.doctor)
        self.doc_client = self.client_class()
        self.doc_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens_doc['access']}")

    @patch('apps.notificaciones.services.NotificationService.enviar_mensaje')
    def test_generar_backup_manual_endpoint(self, mock_notif):
        """HU-302, T-302.1 a T-302.4: Endpoint POST /admin/backup/generar genera backup manual para Superadmin."""
        res = self.sa_client.post('/api/admin/backup/generar', {}, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn('registro_id', res.data)
        self.assertEqual(res.data['origen'], 'MANUAL')

        # Verificar RegistroBackup en base de datos
        registro = RegistroBackup.objects.get(pk=res.data['registro_id'])
        self.assertTrue(registro.exitoso)
        self.assertEqual(registro.origen, 'MANUAL')
        self.assertEqual(registro.usuario_solicitante, self.superadmin)
        self.assertTrue(mock_notif.called)

    def test_generar_backup_restringido_a_superadmin(self):
        """T-302.1: Endpoint POST /admin/backup/generar retorna 403 para usuarios sin rol SUPERADMIN."""
        res = self.doc_client.post('/api/admin/backup/generar', {}, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    @patch('apps.notificaciones.services.NotificationService.enviar_mensaje')
    def test_ejecutar_backup_servicio_automatico(self, mock_notif):
        """T-301.1 a T-301.5: ejecutar_backup genera dump comprimido, notifica y remueve el archivo del servidor."""
        registro = ejecutar_backup(origen='AUTOMATICO')
        self.assertTrue(registro.exitoso)
        self.assertEqual(registro.origen, 'AUTOMATICO')
        self.assertTrue(registro.nombre_archivo.endswith('.sql.gz'))
        self.assertGreater(registro.tamano_bytes, 0)
        self.assertTrue(mock_notif.called)

    def test_consultar_estado_backup(self):
        """T-302.5: Endpoint GET /admin/backup/estado/{id} retorna el detalle del estado del respaldo."""
        reg = RegistroBackup.objects.create(
            nombre_archivo='backup_ceos_2026-08-27.sql.gz',
            tamano_bytes=1024,
            exitoso=True,
            origen='MANUAL',
            usuario_solicitante=self.superadmin
        )
        res = self.sa_client.get(f'/api/admin/backup/estado/{reg.id}')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['registro_id'], reg.id)
        self.assertEqual(res.data['nombre_archivo'], reg.nombre_archivo)
        self.assertEqual(res.data['origen'], 'MANUAL')

    def test_historial_backups_con_filtros(self):
        """HU-303, T-303.1, T-303.2: GET /admin/backup/historial retorna lista paginada y filtrable."""
        RegistroBackup.objects.create(nombre_archivo='b1.sql.gz', tamano_bytes=100, exitoso=True, origen='AUTOMATICO')
        RegistroBackup.objects.create(nombre_archivo='b2.sql.gz', tamano_bytes=200, exitoso=True, origen='MANUAL')
        RegistroBackup.objects.create(nombre_archivo='b3.sql.gz', tamano_bytes=0, exitoso=False, origen='MANUAL')

        res = self.sa_client.get('/api/admin/backup/historial?origen=MANUAL')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['total'], 2)

        res_exitoso = self.sa_client.get('/api/admin/backup/historial?exitoso=false')
        self.assertEqual(res_exitoso.status_code, status.HTTP_200_OK)
        self.assertEqual(res_exitoso.data['total'], 1)
