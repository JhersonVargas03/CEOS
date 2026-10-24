from rest_framework import permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.db import transaction, models
from django.db.models import Q
from django.utils import timezone

from apps.usuarios.permissions import TienePermiso, obtener_permisos_efectivos
from apps.usuarios.models import Usuario
from apps.auditoria.services import AuditService
from apps.notificaciones.models import NotificacionApp
from apps.notificaciones.services import NotificationService
from .models import Area, CategoriaMaterial, Material
from .models_lotes import Lote
from .models_movimientos import MovimientoSalida, MovimientoSalidaLote
from .models_ajustes import AjusteInventario
from .models_solicitudes import SolicitudMaterial
from .constants import ICONOS_DISPONIBLES
from .serializers import (
    AreaSerializer, AreaCreateUpdateSerializer,
    CategoriaMaterialSerializer, CategoriaMaterialCreateUpdateSerializer,
    MaterialSerializer, MaterialCreateSerializer, MaterialUpdateSerializer,
    LoteSerializer, LoteCreateSerializer,
    SalidaCreateSerializer, MovimientoSalidaSerializer,
    AjusteCreateSerializer, AjusteInventarioSerializer,
    SolicitudMaterialSerializer, SolicitudCreateSerializer,
    SolicitudUpdateSerializer, SolicitudResolverSerializer
)


# ─────────────────────────────────────────────────────────────────────
# HU-201: CRUD de Áreas
# ─────────────────────────────────────────────────────────────────────

class AreaListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """T-201.2: Lista todas las áreas activas (accesible por todos los usuarios autenticados)."""
        areas = Area.objects.filter(activo=True).annotate(
            total_materiales_anotados=models.Count('materiales', filter=models.Q(materiales__activo=True))
        )
        return Response(AreaSerializer(areas, many=True).data)

    def post(self, request):
        """
        T-201.3 / T-304.6 / T-304.8: Crea una nueva área.
        Requiere permiso 'gestionar_catalogo_inventario'.
        """
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        serializer = AreaCreateUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        nombre = serializer.validated_data['nombre'].strip()
        if Area.objects.filter(nombre__iexact=nombre).exists():
            return Response({'error': 'Ya existe un área con ese nombre.'},
                            status=status.HTTP_400_BAD_REQUEST)

        area = Area.objects.create(
            nombre=nombre,
            descripcion=serializer.validated_data.get('descripcion', ''),
            icono=serializer.validated_data.get('icono', 'package'),  # T-304.1
        )
        AuditService.registrar_accion(request.user, 'CREACION_AREA', {'area_id': area.id, 'nombre': area.nombre}, request=request)
        return Response(AreaSerializer(area).data, status=status.HTTP_201_CREATED)


class AreaDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, area_id):
        area = get_object_or_404(Area, id=area_id)
        return Response(AreaSerializer(area).data)

    def patch(self, request, area_id):
        """
        T-201.4 / T-304.6 / T-304.8: Edita nombre, descripción e ícono de un área.
        Requiere permiso 'gestionar_catalogo_inventario'.
        """
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        area = get_object_or_404(Area, id=area_id)
        serializer = AreaCreateUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        if 'nombre' in serializer.validated_data:
            nombre = serializer.validated_data['nombre'].strip()
            if Area.objects.filter(nombre__iexact=nombre).exclude(id=area.id).exists():
                return Response({'error': 'Ya existe otra área con ese nombre.'},
                                status=status.HTTP_400_BAD_REQUEST)
            area.nombre = nombre

        if 'descripcion' in serializer.validated_data:
            area.descripcion = serializer.validated_data['descripcion']

        if 'icono' in serializer.validated_data:  # T-304.1
            area.icono = serializer.validated_data['icono']

        area.save()
        AuditService.registrar_accion(request.user, 'EDICION_AREA', {'area_id': area.id}, request=request)
        return Response(AreaSerializer(area).data)

    def delete(self, request, area_id):
        """T-201.5: Desactiva un área. Bloquea si tiene materiales asociados."""
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        area = get_object_or_404(Area, id=area_id)

        if area.materiales.exists():
            return Response(
                {'error': 'No se puede eliminar un área con materiales asociados. Desactive los materiales primero.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        area.activo = False
        area.save()
        AuditService.registrar_accion(request.user, 'DESACTIVACION_AREA', {'area_id': area.id}, request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────────────
# HU-202: CRUD de Categorías
# ─────────────────────────────────────────────────────────────────────

class CategoriaListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """T-202.2 / T-AJUSTE-BK.25: Lista categorías activas. Si se provee ?area_id o ?area, filtra por dicha área."""
        area_id = request.query_params.get('area_id') or request.query_params.get('area')
        categorias = CategoriaMaterial.objects.filter(activo=True)
        if area_id:
            try:
                area_id_int = int(area_id)
                categorias = categorias.filter(
                    models.Q(area_id=area_id_int) | models.Q(materiales__area_id=area_id_int, materiales__activo=True)
                ).distinct()
            except (ValueError, TypeError):
                pass
        return Response(CategoriaMaterialSerializer(categorias, many=True).data)

    def post(self, request):
        """
        T-202.3 / T-304.6 / T-304.8 / T-AJUSTE-BK.25: Crea una nueva categoría.
        Requiere permiso 'gestionar_catalogo_inventario'. Permite asociar a un Área opcionalmente.
        """
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        serializer = CategoriaMaterialCreateUpdateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        nombre = serializer.validated_data['nombre'].strip()
        if CategoriaMaterial.objects.filter(nombre__iexact=nombre).exists():
            return Response({'error': 'Ya existe una categoría con ese nombre.'},
                            status=status.HTTP_400_BAD_REQUEST)

        area_id = serializer.validated_data.get('area_id')
        if not area_id and 'area_id' in request.data:
            try:
                area_id = int(request.data['area_id'])
            except (ValueError, TypeError):
                area_id = None

        area_obj = None
        if area_id:
            try:
                area_obj = Area.objects.get(id=area_id)
            except Area.DoesNotExist:
                return Response({'error': f'Área con ID {area_id} no encontrada.'},
                                status=status.HTTP_400_BAD_REQUEST)

        categoria = CategoriaMaterial.objects.create(
            nombre=nombre,
            descripcion=serializer.validated_data.get('descripcion', ''),
            icono=serializer.validated_data.get('icono', 'package'),  # T-304.2
            area=area_obj,
        )
        AuditService.registrar_accion(request.user, 'CREACION_CATEGORIA', {'categoria_id': categoria.id}, request=request)
        return Response(CategoriaMaterialSerializer(categoria).data, status=status.HTTP_201_CREATED)


class CategoriaDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, categoria_id):
        categoria = get_object_or_404(CategoriaMaterial, id=categoria_id)
        return Response(CategoriaMaterialSerializer(categoria).data)

    def patch(self, request, categoria_id):
        """
        T-202.4 / T-304.6 / T-304.8: Edita nombre, descripción e ícono de una categoría.
        Requiere permiso 'gestionar_catalogo_inventario'.
        """
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        categoria = get_object_or_404(CategoriaMaterial, id=categoria_id)
        serializer = CategoriaMaterialCreateUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        if 'nombre' in serializer.validated_data:
            nombre = serializer.validated_data['nombre'].strip()
            if CategoriaMaterial.objects.filter(nombre__iexact=nombre).exclude(id=categoria.id).exists():
                return Response({'error': 'Ya existe otra categoría con ese nombre.'},
                                status=status.HTTP_400_BAD_REQUEST)
            categoria.nombre = nombre

        if 'descripcion' in serializer.validated_data:
            categoria.descripcion = serializer.validated_data['descripcion']

        if 'icono' in serializer.validated_data:  # T-304.2 / T-304.7
            categoria.icono = serializer.validated_data['icono']

        if 'area_id' in serializer.validated_data:
            area_id = serializer.validated_data['area_id']
            categoria.area_id = area_id

        categoria.save()
        AuditService.registrar_accion(request.user, 'EDICION_CATEGORIA', {'categoria_id': categoria.id}, request=request)
        return Response(CategoriaMaterialSerializer(categoria).data)

    def delete(self, request, categoria_id):
        """T-202.5: Desactiva una categoría."""
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para gestionar catálogo de inventario.'},
                            status=status.HTTP_403_FORBIDDEN)

        categoria = get_object_or_404(CategoriaMaterial, id=categoria_id)

        if categoria.materiales.exists():
            return Response(
                {'error': 'No se puede eliminar una categoría con materiales asociados.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        categoria.activo = False
        categoria.save()
        AuditService.registrar_accion(request.user, 'DESACTIVACION_CATEGORIA', {'categoria_id': categoria.id}, request=request)
        return Response(status=status.HTTP_204_NO_CONTENT)


# ─────────────────────────────────────────────────────────────────────
# HU-304: Catálogo de Íconos Disponibles (Épica 4.A / Extensión)
# ─────────────────────────────────────────────────────────────────────

class IconosDisponiblesView(APIView):
    """
    T-304.5 / T-304.8: Devuelve el catálogo de identificadores de íconos permitidos
    para Área y Categoría de Material (Phosphor Icons).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response({
            'iconos': ICONOS_DISPONIBLES,
            'total': len(ICONOS_DISPONIBLES)
        }, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────
# HU-203 + HU-204: Materiales — Alta, Edición y Búsqueda
# ─────────────────────────────────────────────────────────────────────

class MaterialListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        """T-204.1/T-204.2/T-204.3: Lista materiales con filtros y búsqueda (accesible por todos los usuarios autenticados)."""
        qs = Material.objects.select_related('area', 'categoria').filter(activo=True)

        # T-204.2: Búsqueda parcial case-insensitive (soporta 'q' y 'search')
        q = request.query_params.get('q') or request.query_params.get('search')
        if q:
            qs = qs.filter(
                Q(nombre__icontains=q) |
                Q(descripcion__icontains=q) |
                Q(area__nombre__icontains=q) |
                Q(categoria__nombre__icontains=q)
            )

        area_id = request.query_params.get('area_id')
        if area_id:
            qs = qs.filter(area_id=area_id)

        categoria_id = request.query_params.get('categoria_id')
        if categoria_id:
            qs = qs.filter(categoria_id=categoria_id)

        return Response(MaterialSerializer(qs, many=True).data)

    def post(self, request):
        """T-203.2: Crea un nuevo material."""
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'crear_material' not in permisos_usuario and 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para dar de alta materiales.'},
                            status=status.HTTP_403_FORBIDDEN)

        serializer = MaterialCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        area = get_object_or_404(Area, id=serializer.validated_data['area_id'], activo=True)
        categoria = get_object_or_404(CategoriaMaterial, id=serializer.validated_data['categoria_id'], activo=True)
        nombre = serializer.validated_data['nombre'].strip()

        # T-203.3: Unicidad área + categoría + nombre
        if Material.objects.filter(area=area, categoria=categoria, nombre__iexact=nombre).exists():
            return Response(
                {'error': 'Ya existe un material con ese nombre en la misma área y categoría.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with transaction.atomic():
            material = Material.objects.create(
                nombre=nombre,
                descripcion=serializer.validated_data.get('descripcion', ''),
                area=area,
                categoria=categoria,
                unidad_medida=serializer.validated_data.get('unidad_medida', 'unidad'),
                stock_minimo=serializer.validated_data.get('stock_minimo', 0),
            )
            AuditService.registrar_accion(request.user, 'CREACION_MATERIAL', {'material_id': material.id, 'nombre': material.nombre}, request=request)

            stock_inicial = serializer.validated_data.get('stock_inicial') or serializer.validated_data.get('cantidad_inicial') or 0
            if stock_inicial > 0:
                codigo_lote = serializer.validated_data.get('codigo_lote') or f"LOT-{timezone.now().strftime('%Y%m%d%H%M%S')}"
                lote = Lote.objects.create(
                    material=material,
                    codigo_lote=codigo_lote,
                    cantidad_ingresada=stock_inicial,
                    cantidad_disponible=stock_inicial,
                    costo=serializer.validated_data.get('costo_unitario'),
                    fecha_caducidad=serializer.validated_data.get('fecha_caducidad'),
                )
                AuditService.registrar_accion(
                    request.user,
                    'INGRESO_LOTE',
                    {'lote_id': lote.id, 'codigo_lote': lote.codigo_lote, 'material_id': material.id, 'cantidad': stock_inicial},
                    request=request
                )

        return Response(MaterialSerializer(material).data, status=status.HTTP_201_CREATED)


class MaterialDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, material_id):
        material = get_object_or_404(Material, id=material_id)
        return Response(MaterialSerializer(material).data)

    def patch(self, request, material_id):
        """T-203.4: Edita campos de un material."""
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'gestionar_catalogo_inventario' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para editar materiales.'},
                            status=status.HTTP_403_FORBIDDEN)

        material = get_object_or_404(Material, id=material_id)
        serializer = MaterialUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        for field in ['nombre', 'descripcion', 'unidad_medida', 'stock_minimo', 'activo']:
            if field in serializer.validated_data:
                setattr(material, field, serializer.validated_data[field])

        material.save()
        AuditService.registrar_accion(request.user, 'EDICION_MATERIAL', {'material_id': material.id}, request=request)
        return Response(MaterialSerializer(material).data)


# ─────────────────────────────────────────────────────────────────────
# HU-205 + HU-206: Ingreso y Listado de Lotes (Épica 2.B)
# ─────────────────────────────────────────────────────────────────────

class LoteCreateView(APIView):
    """T-205.2: Registrar ingreso de un nuevo lote."""
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'registrar_entrada'

    def post(self, request):
        serializer = LoteCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        material = get_object_or_404(Material, id=data['material_id'], activo=True)

        costo = data.get('costo')
        costo_registrado = costo is not None

        codigo = data['codigo_lote'].strip()
        fecha_caducidad = data.get('fecha_caducidad')

        # Consolidación: si es Lote General y no tiene caducidad, sumar al lote general existente
        lote_existente = None
        if codigo == 'Lote General' and not fecha_caducidad:
            lote_existente = Lote.objects.filter(
                material=material,
                codigo_lote='Lote General',
                fecha_caducidad__isnull=True
            ).first()

        if lote_existente:
            lote = lote_existente
            lote.cantidad_ingresada += data['cantidad_ingresada']
            lote.cantidad_disponible += data['cantidad_ingresada']
            if costo is not None:
                lote.costo = costo
                lote.costo_registrado = True
            lote.save()
        else:
            lote = Lote.objects.create(
                material=material,
                codigo_lote=codigo,
                cantidad_ingresada=data['cantidad_ingresada'],
                cantidad_disponible=data['cantidad_ingresada'],  # T-205.3: inicializar cantidad_disponible = cantidad_ingresada
                costo=costo,
                costo_registrado=costo_registrado,              # T-205.4
                fecha_ingreso=data.get('fecha_ingreso') or timezone.localdate(),
                fecha_caducidad=fecha_caducidad,
                fecha_alerta_vencimiento=data.get('fecha_alerta_vencimiento'),
                usuario_ingreso=request.user
            )

        # T-205.5: Auditoría
        AuditService.registrar_accion(
            request.user,
            'INGRESO_LOTE',
            {
                'lote_id': lote.id,
                'codigo_lote': lote.codigo_lote,
                'material_id': material.id,
                'cantidad': data['cantidad_ingresada']
            },
            request=request
        )

        return Response(LoteSerializer(lote).data, status=status.HTTP_201_CREATED)


class MaterialLotesListView(APIView):
    """T-206.1: Lista los lotes de un material ordenados por fecha de caducidad."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, material_id):
        material = get_object_or_404(Material, id=material_id)
        qs = Lote.objects.filter(material=material)

        # T-206.3: Excluir por defecto lotes con cantidad_disponible == 0 salvo incluria_agotados=true
        incluir_agotados = request.query_params.get('incluir_agotados', 'false').lower() == 'true'
        if not incluir_agotados:
            qs = qs.filter(cantidad_disponible__gt=0)

        # T-206.1: Ordenado por fecha_caducidad ascendente (nulos al final para items sin vencimiento)
        qs = qs.order_by(models.F('fecha_caducidad').asc(nulls_last=True), '-creado_en')

        return Response(LoteSerializer(qs, many=True).data)


# ─────────────────────────────────────────────────────────────────────
# HU-207 + HU-208: Salidas de Material (FEFO) (Épica 2.C)
# ─────────────────────────────────────────────────────────────────────

def calcular_distribucion_fefo(lotes, cantidad_solicitada):
    """
    T-207.3: Dada una lista/queryset de lotes ordenados por FEFO (fecha_caducidad asc),
    calcula la distribución de cuánto descontar de cada uno para cubrir cantidad_solicitada.
    Retorna (distribucion, exito) donde distribucion es [(lote, cantidad_a_descontar), ...].
    """
    restante = cantidad_solicitada
    distribucion = []
    for lote in lotes:
        if lote.cantidad_disponible <= 0:
            continue
        a_descontar = min(lote.cantidad_disponible, restante)
        distribucion.append((lote, a_descontar))
        restante -= a_descontar
        if restante == 0:
            break
    return distribucion, (restante == 0)


class SalidaCreateView(APIView):
    """
    T-207.4: Endpoint para registrar salida de material con descuento FEFO automático.
    T-207.5: Transacción atómica con bloqueo select_for_update.
    T-208.1 a T-208.3: Bloqueo si la salida supera el stock disponible.
    """
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'registrar_salida'

    def post(self, request):
        serializer = SalidaCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        material_id = serializer.validated_data['material_id']
        cantidad_solicitada = serializer.validated_data['cantidad']
        motivo_destino = serializer.validated_data.get('motivo_destino', '')

        material = get_object_or_404(Material, id=material_id, activo=True)

        with transaction.atomic():
            # T-207.5: Bloqueo a nivel de fila con select_for_update sobre lotes del material
            lotes = list(
                Lote.objects.select_for_update()
                .filter(material=material, cantidad_disponible__gt=0)
                .order_by(models.F('fecha_caducidad').asc(nulls_last=True), 'creado_en')
            )

            stock_disponible_actual = sum(lote.cantidad_disponible for lote in lotes)

            # T-208.1 & T-208.2: Si stock disponible < solicitado, abortar
            if stock_disponible_actual < cantidad_solicitada:
                permisos_efectivos = obtener_permisos_efectivos(request.user)
                puede_ajustar = 'ajustar_inventario' in permisos_efectivos

                return Response({
                    'error': 'Stock insuficiente para realizar la salida solicitada.',
                    'stock_disponible_actual': stock_disponible_actual,
                    'cantidad_solicitada': cantidad_solicitada,
                    'puede_ajustar': puede_ajustar
                }, status=status.HTTP_400_BAD_REQUEST)

            # T-207.3: Calcular distribución FEFO
            distribucion, exito = calcular_distribucion_fefo(lotes, cantidad_solicitada)

            # Descontar de cada lote
            for lote, a_descontar in distribucion:
                lote.cantidad_disponible -= a_descontar
                lote.save()

            # T-207.1: Crear MovimientoSalida
            movimiento = MovimientoSalida.objects.create(
                material=material,
                cantidad_total=cantidad_solicitada,
                motivo_destino=motivo_destino,
                usuario=request.user
            )

            # T-207.2: Crear MovimientoSalidaLote
            for lote, a_descontar in distribucion:
                MovimientoSalidaLote.objects.create(
                    movimiento_salida=movimiento,
                    lote=lote,
                    cantidad_descontada=a_descontar
                )

            # T-207.6: Auditoría
            AuditService.registrar_accion(
                request.user,
                'REGISTRO_SALIDA_FEFO',
                {
                    'movimiento_id': movimiento.id,
                    'material_id': material.id,
                    'cantidad': cantidad_solicitada,
                    'lotes_afectados': [lote.codigo_lote for lote, _ in distribucion]
                },
                request=request
            )

            return Response(MovimientoSalidaSerializer(movimiento).data, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────────────────────────────────
# HU-209 + HU-210: Ajustes de Inventario (Épica 2.D)
# ─────────────────────────────────────────────────────────────────────

class AjusteListCreateView(APIView):
    """
    T-209.2: Endpoint POST /inventario/ajustes para registrar un ajuste manual de existencias.
    T-210.1: Endpoint GET /inventario/ajustes para consultar el historial independiente de ajustes.
    T-209.3: Actualiza lote.cantidad_disponible y crea AjusteInventario inmutable.
    T-209.4: Valida motivo obligatorio.
    """
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'ajustar_inventario'

    def get(self, request):
        qs = AjusteInventario.objects.select_related('lote', 'lote__material', 'usuario').all()

        lote_id = request.query_params.get('lote_id')
        if lote_id:
            qs = qs.filter(lote_id=lote_id)

        material_id = request.query_params.get('material_id')
        if material_id:
            qs = qs.filter(lote__material_id=material_id)

        qs = qs.order_by('-fecha_hora')
        return Response(AjusteInventarioSerializer(qs, many=True).data)

    def post(self, request):
        serializer = AjusteCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors},
                            status=status.HTTP_400_BAD_REQUEST)

        lote_id = serializer.validated_data.get('lote_id')
        material_id = serializer.validated_data.get('material_id')
        cantidad_nueva = serializer.validated_data['cantidad_nueva']
        motivo = serializer.validated_data['motivo']

        if lote_id:
            lote = get_object_or_404(Lote, id=lote_id)
        else:
            material = get_object_or_404(Material, id=material_id, activo=True)
            # Buscar lote general o el último lote activo, o crearlo si no existe
            lote = Lote.objects.filter(material=material, codigo_lote='Lote General').first()
            if not lote:
                lote = Lote.objects.filter(material=material).order_by('-creado_en').first()
            if not lote:
                lote = Lote.objects.create(
                    material=material,
                    codigo_lote='Lote General',
                    cantidad_ingresada=0,
                    cantidad_disponible=0,
                    usuario_ingreso=request.user
                )

        with transaction.atomic():
            # Bloquear fila del lote
            lote_locked = Lote.objects.select_for_update().get(id=lote.id)
            cantidad_anterior = lote_locked.cantidad_disponible

            # Actualizar stock del lote
            lote_locked.cantidad_disponible = cantidad_nueva
            lote_locked.save()

            # Crear registro inmutable de ajuste
            ajuste = AjusteInventario.objects.create(
                lote=lote_locked,
                usuario=request.user,
                cantidad_anterior=cantidad_anterior,
                cantidad_nueva=cantidad_nueva,
                motivo=motivo
            )

            # Audit log
            AuditService.registrar_accion(
                request.user,
                'AJUSTE_INVENTARIO',
                {
                    'ajuste_id': ajuste.id,
                    'lote_id': lote_locked.id,
                    'codigo_lote': lote_locked.codigo_lote,
                    'material_id': lote_locked.material_id,
                    'cantidad_anterior': cantidad_anterior,
                    'cantidad_nueva': cantidad_nueva,
                    'motivo': motivo
                },
                request=request
            )

            return Response(AjusteInventarioSerializer(ajuste).data, status=status.HTTP_201_CREATED)


class MaterialMovimientosListView(APIView):
    """
    Lista el historial unificado y cronológico de movimientos de un material:
    - Entradas (Lote)
    - Salidas (MovimientoSalida)
    - Ajustes manuales (AjusteInventario)
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, material_id):
        material = get_object_or_404(Material, id=material_id)

        movimientos = []

        # 1. Entradas (Lote)
        lotes = Lote.objects.filter(material=material).select_related('usuario_ingreso')
        for l in lotes:
            usuario_nombre = l.usuario_ingreso.username if l.usuario_ingreso else 'Sistema'
            movimientos.append({
                'id': f"entrada-{l.id}",
                'movimiento_id': l.id,
                'tipo': 'entrada',
                'material_id': material.id,
                'material_nombre': material.nombre,
                'cantidad': l.cantidad_ingresada,
                'lote_codigo': l.codigo_lote,
                'usuario_nombre': usuario_nombre,
                'motivo': f"Ingreso lote {l.codigo_lote}" if l.codigo_lote != 'Lote General' else "Ingreso stock general",
                'fecha_hora': l.creado_en.isoformat(),
            })

        # 2. Salidas (MovimientoSalida)
        salidas = MovimientoSalida.objects.filter(material=material).select_related('usuario').prefetch_related('detalles_lote__lote')
        for s in salidas:
            usuario_nombre = s.usuario.username if s.usuario else 'Sistema'
            lotes_str = ", ".join(d.lote.codigo_lote for d in s.detalles_lote.all())
            movimientos.append({
                'id': f"salida-{s.id}",
                'movimiento_id': s.id,
                'tipo': 'salida',
                'material_id': material.id,
                'material_nombre': material.nombre,
                'cantidad': s.cantidad_total,
                'lote_codigo': lotes_str,
                'usuario_nombre': usuario_nombre,
                'motivo': s.motivo_destino or 'Salida por atención clínica',
                'fecha_hora': s.fecha_hora.isoformat(),
            })

        # 3. Ajustes (AjusteInventario)
        ajustes = AjusteInventario.objects.filter(lote__material=material).select_related('usuario', 'lote')
        for a in ajustes:
            usuario_nombre = a.usuario.username if a.usuario else 'Sistema'
            movimientos.append({
                'id': f"ajuste-{a.id}",
                'movimiento_id': a.id,
                'tipo': 'ajuste',
                'material_id': material.id,
                'material_nombre': material.nombre,
                'cantidad': a.cantidad_nueva,
                'cantidad_anterior': a.cantidad_anterior,
                'cantidad_nueva': a.cantidad_nueva,
                'lote_codigo': a.lote.codigo_lote,
                'usuario_nombre': usuario_nombre,
                'motivo': a.motivo,
                'fecha_hora': a.fecha_hora.isoformat(),
            })

        # Ordenar por fecha descendente
        movimientos.sort(key=lambda m: m['fecha_hora'], reverse=True)

        return Response(movimientos, status=status.HTTP_200_OK)


# ─────────────────────────────────────────────────────────────────────
# HU-211 a HU-214: Solicitudes de Material (Épica 2.E)
# ─────────────────────────────────────────────────────────────────────

class SolicitudListCreateView(APIView):
    """
    T-211.2: Endpoint POST /inventario/solicitudes para crear solicitudes.
    T-213.1 & T-214.1: Endpoint GET /inventario/solicitudes para consultar solicitudes (propias o globales).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        permisos_usuario = obtener_permisos_efectivos(request.user)

        # Gestores, Admins y Superadmins ven todas las solicitudes. Usuarios normales solo ven las propias.
        if 'aprobar_solicitud' in permisos_usuario or 'ver_reportes_globales' in permisos_usuario or request.user.is_superuser:
            qs = SolicitudMaterial.objects.select_related('solicitante', 'material', 'area', 'resuelto_por').all()
        else:
            qs = SolicitudMaterial.objects.select_related('solicitante', 'material', 'area', 'resuelto_por').filter(solicitante=request.user)

        # Filtros de consulta (T-214.2)
        estado = request.query_params.get('estado')
        if estado:
            qs = qs.filter(estado=estado)

        material_id = request.query_params.get('material_id')
        if material_id:
            qs = qs.filter(material_id=material_id)

        solicitante_id = request.query_params.get('solicitante_id')
        if solicitante_id:
            qs = qs.filter(solicitante_id=solicitante_id)

        return Response(SolicitudMaterialSerializer(qs, many=True).data)

    def post(self, request):
        permisos_usuario = obtener_permisos_efectivos(request.user)
        if 'solicitar_material' not in permisos_usuario and not request.user.is_superuser:
            return Response({'error': 'No posee permisos para solicitar materiales.'}, status=status.HTTP_403_FORBIDDEN)

        serializer = SolicitudCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        material_id = serializer.validated_data.get('material_id')
        nombre_material_nuevo = serializer.validated_data.get('nombre_material_nuevo', '').strip()
        area_id = serializer.validated_data.get('area_id')
        unidad_medida = serializer.validated_data.get('unidad_medida', 'unidades').strip() or 'unidades'
        cantidad_solicitada = serializer.validated_data['cantidad_solicitada']
        motivo = serializer.validated_data.get('motivo', '').strip()

        material = None
        area = None
        if material_id:
            material = get_object_or_404(Material, id=material_id)
            nombre_mostrar = material.nombre
            area = material.area
            unidad_medida = material.unidad_medida
        else:
            nombre_mostrar = f"{nombre_material_nuevo} (Nuevo)"
            if area_id:
                from .models import Area
                area = Area.objects.filter(id=area_id).first()

        # T-211.3: Sugerencia de motivo 'sin_stock' si se omite o si el stock total del material es 0
        if not motivo:
            motivo = 'sin_stock'

        # T-211.4: Estado inicial 'pendiente'
        solicitud = SolicitudMaterial.objects.create(
            solicitante=request.user,
            material=material,
            nombre_material_nuevo=nombre_material_nuevo,
            area=area,
            unidad_medida=unidad_medida,
            cantidad_solicitada=cantidad_solicitada,
            motivo=motivo,
            estado='pendiente'
        )

        # T-211.5 & T-211.6: Notificación In-App y externa a encargados (gestores/admins)
        encargados = Usuario.objects.filter(
            activo=True,
            roles__permisos__codigo__in=['aprobar_solicitud', 'ajustar_inventario']
        ).distinct()

        for encargado in encargados:
            NotificacionApp.objects.create(
                usuario=encargado,
                titulo='Nueva Solicitud de Material',
                mensaje=f"El usuario {request.user.username} solicitó {cantidad_solicitada} {unidad_medida} de {nombre_mostrar}.",
                tipo='solicitud_creada',
                referencia_id=solicitud.id
            )
            NotificationService.enviar_mensaje(
                encargado,
                f"📦 <b>NUEVA SOLICITUD DE MATERIAL</b>\n\nUsuario: {request.user.username}\nMaterial: {nombre_mostrar}\nCantidad: {cantidad_solicitada} {unidad_medida}"
            )

        # Auditoría
        AuditService.registrar_accion(
            request.user,
            'CREACION_SOLICITUD_MATERIAL',
            {
                'solicitud_id': solicitud.id,
                'material_id': material.id if material else None,
                'nombre_material_nuevo': nombre_material_nuevo if not material else None,
                'cantidad': cantidad_solicitada,
                'motivo': motivo
            },
            request=request
        )

        return Response(SolicitudMaterialSerializer(solicitud).data, status=status.HTTP_201_CREATED)


class SolicitudDetailView(APIView):
    """
    T-212.1 & T-212.2: Endpoint PATCH /inventario/solicitudes/{id} para editar una solicitud propia en estado pendiente.
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, solicitud_id):
        solicitud = get_object_or_404(SolicitudMaterial, id=solicitud_id)

        # Validar dueño
        if solicitud.solicitante != request.user:
            return Response({'error': 'No puede editar una solicitud creada por otro usuario.'}, status=status.HTTP_403_FORBIDDEN)

        # Validar estado pendiente
        if solicitud.estado != 'pendiente':
            return Response({'error': 'Solo se pueden modificar solicitudes en estado pendiente.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = SolicitudUpdateSerializer(data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        if 'cantidad_solicitada' in serializer.validated_data:
            solicitud.cantidad_solicitada = serializer.validated_data['cantidad_solicitada']
        if 'motivo' in serializer.validated_data:
            solicitud.motivo = serializer.validated_data['motivo'].strip() or 'sin_stock'

        solicitud.save()

        # T-212.4: Auditoría
        AuditService.registrar_accion(
            request.user,
            'EDICION_SOLICITUD_MATERIAL',
            {
                'solicitud_id': solicitud.id,
                'cantidad_nueva': solicitud.cantidad_solicitada,
                'motivo_nuevo': solicitud.motivo
            },
            request=request
        )

        return Response(SolicitudMaterialSerializer(solicitud).data)


class SolicitudCancelarView(APIView):
    """
    T-212.3: Endpoint POST /inventario/solicitudes/{id}/cancelar para cancelar una solicitud propia en estado pendiente.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, solicitud_id):
        solicitud = get_object_or_404(SolicitudMaterial, id=solicitud_id)

        # Validar dueño
        if solicitud.solicitante != request.user:
            return Response({'error': 'No puede cancelar una solicitud creada por otro usuario.'}, status=status.HTTP_403_FORBIDDEN)

        # Validar estado pendiente
        if solicitud.estado != 'pendiente':
            return Response({'error': 'Solo se pueden cancelar solicitudes en estado pendiente.'}, status=status.HTTP_400_BAD_REQUEST)

        solicitud.estado = 'cancelada'
        solicitud.save()

        # T-212.4: Auditoría
        AuditService.registrar_accion(
            request.user,
            'CANCELACION_SOLICITUD_MATERIAL',
            {'solicitud_id': solicitud.id},
            request=request
        )

        return Response(SolicitudMaterialSerializer(solicitud).data)


class SolicitudResolverView(APIView):
    """
    T-213.2 a T-213.6: Endpoint POST /inventario/solicitudes/{id}/resolver para aprobar o rechazar solicitudes.
    Requiere permiso 'aprobar_solicitud'.
    """
    permission_classes = [permissions.IsAuthenticated, TienePermiso]
    codigo_permiso = 'aprobar_solicitud'

    def post(self, request, solicitud_id):
        solicitud = get_object_or_404(SolicitudMaterial, id=solicitud_id)

        if solicitud.estado != 'pendiente':
            return Response({'error': 'Esta solicitud ya ha sido resuelta o cancelada.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = SolicitudResolverSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'error': 'Datos inválidos', 'detalles': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        accion = serializer.validated_data['accion']
        comentario = serializer.validated_data['comentario']

        if accion == 'aprobar':
            solicitud.estado = 'aprobada'
        else:
            solicitud.estado = 'rechazada'

        solicitud.comentario_resolucion = comentario
        solicitud.resuelto_por = request.user
        solicitud.fecha_resolucion = timezone.now()
        solicitud.save()

        # T-213.5: Notificación In-App y externa al solicitante
        NotificacionApp.objects.create(
            usuario=solicitud.solicitante,
            titulo=f"Solicitud #{solicitud.id} {solicitud.estado.capitalize()}",
            mensaje=f"Tu solicitud de {solicitud.cantidad_solicitada} {solicitud.material.nombre} fue {solicitud.estado}. Comentario: {comentario or 'Sin comentarios'}",
            tipo='solicitud_resuelta',
            referencia_id=solicitud.id
        )
        NotificationService.enviar_mensaje(
            solicitud.solicitante,
            f"📋 <b>SOLICITUD {solicitud.estado.upper()}</b>\n\nMaterial: {solicitud.material.nombre}\nCantidad: {solicitud.cantidad_solicitada}\nResuelto por: {request.user.username}\nComentario: {comentario or 'N/A'}"
        )

        # T-213.6: Auditoría
        AuditService.registrar_accion(
            request.user,
            'RESOLUCION_SOLICITUD_MATERIAL',
            {
                'solicitud_id': solicitud.id,
                'estado_nuevo': solicitud.estado,
                'comentario': comentario
            },
            request=request
        )

        return Response(SolicitudMaterialSerializer(solicitud).data)





