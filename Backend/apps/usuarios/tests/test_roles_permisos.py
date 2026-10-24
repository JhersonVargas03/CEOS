from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from django.core.cache import cache
from apps.usuarios.models import Usuario, Rol, Permiso, UsuarioRol, obtener_permisos_efectivos, PERMISOS_MODO_CONGELADO
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario

class RolesPermisosEpica1BTestCase(TestCase):
    def setUp(self):
        cache.clear()
        cargar_seeds_roles_y_permisos()

        self.client = APIClient()

        # Crear Superadmin
        self.superadmin = Usuario.objects.create_superuser(
            username='SuperUser',
            correo_interno='superadmin@clinica.com',
            password='Password123!'
        )
        self.superadmin_tokens = generar_tokens_para_usuario(self.superadmin)

        # Crear Doctor activo
        self.doctor = Usuario.objects.create_user(
            username='DoctorHouse',
            correo_interno='house@clinica.com',
            password='Password123!'
        )
        rol_doctor = Rol.objects.get(nombre='Doctor')
        UsuarioRol.objects.create(usuario=self.doctor, rol=rol_doctor)
        self.doctor_tokens = generar_tokens_para_usuario(self.doctor)

    def test_t105_1_to_5_seeds_permisos_y_roles_fabrica(self):
        """T-105.1 a T-105.5: Carga inicial de permisos base y roles de fábrica."""
        self.assertGreaterEqual(Permiso.objects.count(), 12)
        self.assertTrue(Rol.objects.filter(nombre='Superadmin', es_superadmin=True).exists())
        self.assertTrue(Rol.objects.filter(nombre='Doctor', es_de_fabrica=True).exists())

    def test_t105_6_to_8_crud_roles_dinamicos(self):
        """T-105.6 a T-105.8: Crear, editar y listar roles dinámicos."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.superadmin_tokens["access"]}')

        # 1. Crear nuevo rol "Enfermero"
        res_create = self.client.post('/api/admin/roles', {
            'nombre': 'Enfermero',
            'descripcion': 'Personal de enfermería',
            'permisos_codigos': ['solicitar_material', 'ver_mi_historial']
        }, format='json')
        self.assertEqual(res_create.status_code, status.HTTP_201_CREATED)
        rol_id = res_create.data['id']

        # 2. Listar roles
        res_list = self.client.get('/api/admin/roles')
        self.assertEqual(res_list.status_code, status.HTTP_200_OK)
        nombres_roles = [r['nombre'] for r in res_list.data]
        self.assertIn('Enfermero', nombres_roles)

        # 3. Editar rol creado (PATCH)
        res_patch = self.client.patch(f'/api/admin/roles/{rol_id}', {
            'descripcion': 'Personal de enfermería de guardia',
            'permisos_codigos': ['solicitar_material', 'ver_mi_historial', 'registrar_salida']
        }, format='json')
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_patch.data['permisos']), 3)

    def test_t105_9_10_proteccion_superadmin_y_de_fabrica(self):
        """T-105.9, T-105.10: Rechazar edición/eliminación de rol Superadmin o roles con usuarios."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.superadmin_tokens["access"]}')

        rol_superadmin = Rol.objects.get(nombre='Superadmin')
        
        # Intentar modificar rol Superadmin -> 403
        res_edit_sa = self.client.patch(f'/api/admin/roles/{rol_superadmin.id}', {
            'nombre': 'SuperadminEditado'
        }, format='json')
        self.assertEqual(res_edit_sa.status_code, status.HTTP_403_FORBIDDEN)

        # Intentar eliminar rol Doctor (asignado al doctor activo) -> 403/400
        rol_doctor = Rol.objects.get(nombre='Doctor')
        res_del_doc = self.client.delete(f'/api/admin/roles/{rol_doctor.id}')
        self.assertIn(res_del_doc.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_400_BAD_REQUEST])

    def test_t106_1_to_4_asignacion_multiple_roles_y_union_permisos(self):
        """T-106.1 a T-106.4: Asignar múltiples roles y verificar unión de permisos efectivos."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.superadmin_tokens["access"]}')

        rol_gestor = Rol.objects.get(nombre='GestorInventario')
        rol_doctor = Rol.objects.get(nombre='Doctor')

        # Asignar ambos roles al doctor
        res_roles = self.client.patch(f'/api/admin/usuarios/{self.doctor.id}/roles', {
            'roles_ids': [rol_gestor.id, rol_doctor.id]
        }, format='json')
        self.assertEqual(res_roles.status_code, status.HTTP_200_OK)

        # Verificar permisos efectivos del doctor
        permisos_efectivos = obtener_permisos_efectivos(self.doctor)
        self.assertIn('registrar_salida', permisos_efectivos)
        self.assertIn('registrar_entrada', permisos_efectivos)
        self.assertIn('solicitar_material', permisos_efectivos)

    def test_t107_1_to_4_degradacion_permisos_usuario_desactivado(self):
        """T-107.1 a T-107.4: Usuario desactivado recibe únicamente PERMISOS_MODO_CONGELADO y rechaza endpoints."""
        # Confirmar permisos activos antes de desactivar
        permisos_antes = obtener_permisos_efectivos(self.doctor)
        self.assertIn('registrar_salida', permisos_antes)

        # Desactivar usuario doctor
        self.doctor.activo = False
        self.doctor.save()

        # T-107.2: obtener_permisos_efectivos retorna SOLO modo congelado
        permisos_despues = obtener_permisos_efectivos(self.doctor)
        self.assertEqual(set(permisos_despues), set(PERMISOS_MODO_CONGELADO))

        # Intentar acceder a un endpoint restringido (ej. /api/admin/roles) con el usuario desactivado -> 403
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.doctor_tokens["access"]}')
        res_restringido = self.client.get('/api/admin/roles')
        self.assertEqual(res_restringido.status_code, status.HTTP_403_FORBIDDEN)
