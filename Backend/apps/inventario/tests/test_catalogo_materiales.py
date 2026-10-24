from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from apps.usuarios.models import Usuario
from apps.usuarios.seeds import cargar_seeds_roles_y_permisos
from apps.usuarios.tokens import generar_tokens_para_usuario
from apps.inventario.models import Area, CategoriaMaterial, Material
from apps.inventario.models_lotes import Lote


class CatalogoMaterialesEpica2ATestCase(TestCase):
    """T-201.1 a T-204.4 y T-201.T: Suite de tests para Épica 2.A — Catálogo de Materiales."""

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Admin con permiso gestionar_inventario
        self.admin = Usuario.objects.create_superuser(
            username='AdminInventario',
            correo_interno='admininv@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

    def test_hu201_crud_areas(self):
        """T-201.1 a T-201.5: CRUD completo de Áreas."""
        # T-201.3: POST /inventario/areas
        res_post = self.client.post('/api/inventario/areas', {
            'nombre': 'Pabellón Central',
            'descripcion': 'Área Quirúrgica'
        }, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_201_CREATED)
        area_id = res_post.data['id']

        # T-201.2: GET /inventario/areas
        res_get = self.client.get('/api/inventario/areas')
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(len(res_get.data), 1)

        # T-201.4: PATCH /inventario/areas/{id}
        res_patch = self.client.patch(f'/api/inventario/areas/{area_id}', {
            'descripcion': 'Área Quirúrgica Principal'
        }, format='json')
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(res_patch.data['descripcion'], 'Área Quirúrgica Principal')

        # T-201.5: DELETE /inventario/areas/{id} (Desactivación)
        res_del = self.client.delete(f'/api/inventario/areas/{area_id}')
        self.assertEqual(res_del.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Area.objects.get(id=area_id).activo)

    def test_hu201_5_bloqueo_delete_area_con_materiales(self):
        """T-201.5: DELETE debe fallar si el área tiene materiales asociados."""
        area = Area.objects.create(nombre='Odontología')
        cat = CategoriaMaterial.objects.create(nombre='Consumibles')
        Material.objects.create(nombre='Brazalete', area=area, categoria=cat)

        res_del = self.client.delete(f'/api/inventario/areas/{area.id}')
        self.assertEqual(res_del.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('asociados', res_del.data['error'])

    def test_hu202_crud_categorias(self):
        """T-202.1 a T-202.5: CRUD completo de Categorías."""
        # T-202.3: POST /inventario/categorias
        res_post = self.client.post('/api/inventario/categorias', {
            'nombre': 'Insumos Médicos',
            'descripcion': 'Gasas, jeringas, etc.'
        }, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_201_CREATED)
        cat_id = res_post.data['id']

        # T-202.2: GET /inventario/categorias
        res_get = self.client.get('/api/inventario/categorias')
        self.assertEqual(res_get.status_code, status.HTTP_200_OK)

        # T-202.4: PATCH /inventario/categorias/{id}
        res_patch = self.client.patch(f'/api/inventario/categorias/{cat_id}', {
            'nombre': 'Insumos Médicos Desechables'
        }, format='json')
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)

        # T-202.5: DELETE /inventario/categorias/{id}
        res_del = self.client.delete(f'/api/inventario/categorias/{cat_id}')
        self.assertEqual(res_del.status_code, status.HTTP_204_NO_CONTENT)

    def test_hu203_alta_y_unicidad_material(self):
        """T-203.1 a T-203.5: Alta de material, unicidad (área+categoría+nombre) y cálculo de stock."""
        area = Area.objects.create(nombre='Emergencias')
        cat = CategoriaMaterial.objects.create(nombre='Fármacos')

        # T-203.2: POST /inventario/materiales
        res = self.client.post('/api/inventario/materiales', {
            'nombre': 'Paracetamol 500mg',
            'descripcion': 'Analgésico',
            'area_id': area.id,
            'categoria_id': cat.id,
            'unidad_medida': 'caja',
            'stock_minimo': 10
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        mat_id = res.data['id']

        # T-203.3: Unicidad área+categoría+nombre (debe fallar la duplicación)
        res_duplicado = self.client.post('/api/inventario/materiales', {
            'nombre': 'Paracetamol 500mg',
            'area_id': area.id,
            'categoria_id': cat.id
        }, format='json')
        self.assertEqual(res_duplicado.status_code, status.HTTP_400_BAD_REQUEST)

        # T-203.4: PATCH /inventario/materiales/{id}
        res_patch = self.client.patch(f'/api/inventario/materiales/{mat_id}', {
            'stock_minimo': 20
        }, format='json')
        self.assertEqual(res_patch.status_code, status.HTTP_200_OK)
        self.assertEqual(res_patch.data['stock_minimo'], 20)

        # T-203.5: Cálculo de stock_total_disponible
        mat = Material.objects.get(id=mat_id)
        self.assertEqual(mat.stock_total_disponible(), 0)

        Lote.objects.create(material=mat, codigo_lote='L1', cantidad_ingresada=50, cantidad_disponible=50)
        Lote.objects.create(material=mat, codigo_lote='L2', cantidad_ingresada=30, cantidad_disponible=30)
        self.assertEqual(mat.stock_total_disponible(), 80)

    def test_hu204_busqueda_y_filtrado_materiales(self):
        """T-204.1 a T-204.4: Búsqueda y filtrado de materiales."""
        area1 = Area.objects.create(nombre='Laboratorio')
        area2 = Area.objects.create(nombre='Rayos X')
        cat = CategoriaMaterial.objects.create(nombre='Reactivos')

        m1 = Material.objects.create(nombre='Alcohol 70%', area=area1, categoria=cat)
        m2 = Material.objects.create(nombre='Jabón antiséptico', area=area2, categoria=cat)

        # Búsqueda q case-insensitive
        res_q = self.client.get('/api/inventario/materiales?q=alcohol')
        self.assertEqual(res_q.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_q.data), 1)
        self.assertEqual(res_q.data[0]['nombre'], 'Alcohol 70%')

        # Filtrado por area_id
        res_area = self.client.get(f'/api/inventario/materiales?area_id={area2.id}')
        self.assertEqual(res_area.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res_area.data), 1)
        self.assertEqual(res_area.data[0]['nombre'], 'Jabón antiséptico')


class IconosCatalogoEpica4ATestCase(TestCase):
    """
    T-304.1 a T-304.8 y T-304.T: Suite de tests para HU-304 / Épica 4.A (extensión) —
    Íconos para Catálogo de Áreas y Categorías.
    """

    def setUp(self):
        cargar_seeds_roles_y_permisos()
        self.client = APIClient()

        # Admin con permiso gestionar_catalogo_inventario
        self.admin = Usuario.objects.create_superuser(
            username='AdminIconos',
            correo_interno='adminiconos@clinica.com',
            password='Password123!'
        )
        self.admin_tokens = generar_tokens_para_usuario(self.admin)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_tokens["access"]}')

    def test_t304_1_y_3_area_campo_icono_y_fallback(self):
        """T-304.1 y T-304.3: Modelo Area tiene campo icono y asigna 'package' por defecto."""
        area = Area.objects.create(nombre='Consultorio 1')
        self.assertEqual(area.icono, 'package')

        # Creación vía endpoint sin especificar icono -> fallback 'package'
        res = self.client.post('/api/inventario/areas', {
            'nombre': 'Consultorio 2',
            'descripcion': 'Atención general'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['icono'], 'package')

    def test_t304_2_y_3_categoria_campo_icono_y_fallback(self):
        """T-304.2 y T-304.3: Modelo CategoriaMaterial tiene campo icono y asigna 'package' por defecto."""
        cat = CategoriaMaterial.objects.create(nombre='Ortodoncia')
        self.assertEqual(cat.icono, 'package')

        # Creación vía endpoint sin especificar icono -> fallback 'package'
        res = self.client.post('/api/inventario/categorias', {
            'nombre': 'Endodoncia',
            'descripcion': 'Insumos de endodoncia'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['icono'], 'package')

    def test_t304_4_catalogo_iconos_validos(self):
        """T-304.4: Constantes y función de validación de íconos disponibles."""
        from apps.inventario.constants import ICONOS_DISPONIBLES, es_icono_valido

        self.assertIn('package', ICONOS_DISPONIBLES)
        self.assertIn('tooth', ICONOS_DISPONIBLES)
        self.assertIn('syringe', ICONOS_DISPONIBLES)
        self.assertIn('pill', ICONOS_DISPONIBLES)
        self.assertIn('lips', ICONOS_DISPONIBLES)
        self.assertIn('dentistry', ICONOS_DISPONIBLES)
        self.assertIn('local_pharmacy', ICONOS_DISPONIBLES)
        self.assertTrue(es_icono_valido('tooth'))
        self.assertTrue(es_icono_valido('package'))
        self.assertTrue(es_icono_valido('lips'))
        self.assertTrue(es_icono_valido('labios'))
        self.assertTrue(es_icono_valido('dentistry'))
        self.assertFalse(es_icono_valido('icono_inexistente_xyz'))
        self.assertFalse(es_icono_valido(''))

    def test_t304_5_endpoint_iconos_disponibles(self):
        """T-304.5: Endpoint GET /inventario/iconos-disponibles retorna catálogo de íconos."""
        res = self.client.get('/api/inventario/iconos-disponibles')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('iconos', res.data)
        self.assertIn('total', res.data)
        self.assertIn('package', res.data['iconos'])
        self.assertIn('tooth', res.data['iconos'])
        self.assertIn('syringe', res.data['iconos'])
        self.assertEqual(res.data['total'], len(res.data['iconos']))

    def test_t304_6_serializers_area_y_categoria(self):
        """T-304.6: Serializers incluyen campo icono tanto en lectura como escritura."""
        from apps.inventario.serializers import (
            AreaSerializer, AreaCreateUpdateSerializer,
            CategoriaMaterialSerializer, CategoriaMaterialCreateUpdateSerializer
        )

        area = Area.objects.create(nombre='Laboratorio Dental', icono='tooth')
        area_data = AreaSerializer(area).data
        self.assertIn('icono', area_data)
        self.assertEqual(area_data['icono'], 'tooth')

        area_ser = AreaCreateUpdateSerializer(data={'nombre': 'Lab 2', 'icono': 'microscope'})
        self.assertTrue(area_ser.is_valid())
        self.assertEqual(area_ser.validated_data['icono'], 'microscope')

        cat = CategoriaMaterial.objects.create(nombre='Instrumental', icono='scissors')
        cat_data = CategoriaMaterialSerializer(cat).data
        self.assertIn('icono', cat_data)
        self.assertEqual(cat_data['icono'], 'scissors')

        cat_ser = CategoriaMaterialCreateUpdateSerializer(data={'nombre': 'Insumos', 'icono': 'needle'})
        self.assertTrue(cat_ser.is_valid())
        self.assertEqual(cat_ser.validated_data['icono'], 'needle')

    def test_t304_7_creacion_y_edicion_con_icono_valido(self):
        """T-304.7: Creación y edición con ícono válido en Área y Categoría."""
        # Área con ícono válido
        res_area = self.client.post('/api/inventario/areas', {
            'nombre': 'Área Odontológica',
            'icono': 'tooth'
        }, format='json')
        self.assertEqual(res_area.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_area.data['icono'], 'tooth')
        area_id = res_area.data['id']

        # Editar ícono de Área
        res_patch_area = self.client.patch(f'/api/inventario/areas/{area_id}', {
            'icono': 'first_aid_kit'
        }, format='json')
        self.assertEqual(res_patch_area.status_code, status.HTTP_200_OK)
        self.assertEqual(res_patch_area.data['icono'], 'first_aid_kit')

        # Categoría con ícono válido
        res_cat = self.client.post('/api/inventario/categorias', {
            'nombre': 'Anestésicos',
            'icono': 'syringe'
        }, format='json')
        self.assertEqual(res_cat.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_cat.data['icono'], 'syringe')
        cat_id = res_cat.data['id']

        # Editar ícono de Categoría
        res_patch_cat = self.client.patch(f'/api/inventario/categorias/{cat_id}', {
            'icono': 'pill'
        }, format='json')
        self.assertEqual(res_patch_cat.status_code, status.HTTP_200_OK)
        self.assertEqual(res_patch_cat.data['icono'], 'pill')

    def test_t304_7_rechazo_iconos_invalidos_post_y_patch(self):
        """T-304.7: Rechazo con HTTP 400 al enviar íconos no existentes en el catálogo."""
        # POST Área con ícono inválido
        res_area_inv = self.client.post('/api/inventario/areas', {
            'nombre': 'Área Inválida',
            'icono': 'icono_no_existente_123'
        }, format='json')
        self.assertEqual(res_area_inv.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detalles', res_area_inv.data)
        self.assertIn('icono', res_area_inv.data['detalles'])

        # PATCH Área con ícono inválido
        area = Area.objects.create(nombre='Área Existente', icono='package')
        res_patch_inv = self.client.patch(f'/api/inventario/areas/{area.id}', {
            'icono': 'invalido_total'
        }, format='json')
        self.assertEqual(res_patch_inv.status_code, status.HTTP_400_BAD_REQUEST)

        # POST Categoría con ícono inválido
        res_cat_inv = self.client.post('/api/inventario/categorias', {
            'nombre': 'Cat Inválida',
            'icono': 'icono_no_existente_456'
        }, format='json')
        self.assertEqual(res_cat_inv.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('detalles', res_cat_inv.data)
        self.assertIn('icono', res_cat_inv.data['detalles'])

        # PATCH Categoría con ícono inválido
        cat = CategoriaMaterial.objects.create(nombre='Cat Existente', icono='package')
        res_patch_cat_inv = self.client.patch(f'/api/inventario/categorias/{cat.id}', {
            'icono': 'invalido_cat'
        }, format='json')
        self.assertEqual(res_patch_cat_inv.status_code, status.HTTP_400_BAD_REQUEST)

    def test_t304_3_migracion_registros_preexistentes(self):
        """T-304.3: Registros preexistentes conservan icono no nulo con valor por defecto."""
        area = Area.objects.create(nombre='Área Preexistente')
        cat = CategoriaMaterial.objects.create(nombre='Categoría Preexistente')
        self.assertIsNotNone(area.icono)
        self.assertIsNotNone(cat.icono)
        self.assertEqual(area.icono, 'package')
        self.assertEqual(cat.icono, 'package')

    def test_t_ajuste_bk_25_categoria_filtro_por_area_y_creacion(self):
        """T-AJUSTE-BK.25: Creación de categoría vinculada a un área y filtrado por ?area_id."""
        area_odo = Area.objects.create(nombre='Odontología General', icono='tooth')
        area_est = Area.objects.create(nombre='Estética Facial', icono='lips')

        # Crear categoría asociada a Odontología
        res = self.client.post('/api/inventario/categorias', {
            'nombre': 'Implantes y Prótesis',
            'descripcion': 'Insumos dentales',
            'icono': 'tooth',
            'area_id': area_odo.id,
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['area_id'], area_odo.id)
        self.assertEqual(res.data['area_nombre'], 'Odontología General')

        # Crear categoría asociada a Estética
        res_est = self.client.post('/api/inventario/categorias', {
            'nombre': 'Ácidos Hialurónicos',
            'descripcion': 'Insumos estéticos',
            'icono': 'sparkle',
            'area_id': area_est.id,
        }, format='json')
        self.assertEqual(res_est.status_code, status.HTTP_201_CREATED)

        # GET con ?area_id de Odontología debe incluir Implantes pero NO Ácidos
        res_filtro_odo = self.client.get(f'/api/inventario/categorias?area_id={area_odo.id}')
        self.assertEqual(res_filtro_odo.status_code, status.HTTP_200_OK)
        nombres_odo = [c['nombre'] for c in res_filtro_odo.data]
        self.assertIn('Implantes y Prótesis', nombres_odo)
        self.assertNotIn('Ácidos Hialurónicos', nombres_odo)

        # GET con ?area_id de Estética debe incluir Ácidos pero NO Implantes
        res_filtro_est = self.client.get(f'/api/inventario/categorias?area_id={area_est.id}')
        self.assertEqual(res_filtro_est.status_code, status.HTTP_200_OK)
        nombres_est = [c['nombre'] for c in res_filtro_est.data]
        self.assertIn('Ácidos Hialurónicos', nombres_est)
        self.assertNotIn('Implantes y Prótesis', nombres_est)


