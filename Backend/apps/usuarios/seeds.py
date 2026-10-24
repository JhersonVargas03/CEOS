from .models import Permiso, Rol, RolPermiso

PERMISOS_BASE = [
    {"codigo": "gestionar_roles", "nombre": "Gestionar Roles", "descripcion": "Crear, editar, listar y eliminar roles dinámicos"},
    {"codigo": "gestionar_usuarios", "nombre": "Gestionar Usuarios", "descripcion": "Crear, editar, activar, desactivar y resetear cuentas de usuarios"},
    {"codigo": "gestionar_catalogo_inventario", "nombre": "Gestionar Catálogo Inventario", "descripcion": "Crear, editar y eliminar áreas, categorías y materiales"},
    {"codigo": "crear_material", "nombre": "Crear Material", "descripcion": "Dar de alta nuevos materiales en el catálogo"},
    {"codigo": "registrar_entrada", "nombre": "Registrar Entrada", "descripcion": "Registrar ingreso de lotes de material"},
    {"codigo": "registrar_salida", "nombre": "Registrar Salida", "descripcion": "Registrar salida de material con descuento FEFO"},
    {"codigo": "ajustar_inventario", "nombre": "Ajustar Inventario", "descripcion": "Realizar ajustes manuales de stock trazables"},
    {"codigo": "solicitar_material", "nombre": "Solicitar Material", "descripcion": "Crear solicitudes de reposición preventiva o por falta de stock"},
    {"codigo": "aprobar_solicitud", "nombre": "Aprobar Solicitud", "descripcion": "Aprobar o rechazar solicitudes de reposición de materiales"},
    {"codigo": "ver_reportes_globales", "nombre": "Ver Reportes Globales", "descripcion": "Consultar reportes consolidados y dashboards de inventario"},
    {"codigo": "ver_mi_historial", "nombre": "Ver Mi Historial", "descripcion": "Consultar el historial propio de acciones realizadas"},
    {"codigo": "ver_mis_reportes", "nombre": "Ver Mis Reportes", "descripcion": "Consultar reportes propios"},
]

ROLES_FABRICA = [
    {
        "nombre": "Superadmin",
        "descripcion": "Rol principal de administración del sistema",
        "es_superadmin": True,
        "es_de_fabrica": True,
        "permisos": ["gestionar_roles", "gestionar_usuarios", "gestionar_catalogo_inventario", "crear_material", "registrar_entrada", "registrar_salida", "ajustar_inventario", "solicitar_material", "aprobar_solicitud", "ver_reportes_globales", "ver_mi_historial", "ver_mis_reportes"]
    },
    {
        "nombre": "Administrador",
        "descripcion": "Administrador operativo de la clínica",
        "es_superadmin": False,
        "es_de_fabrica": True,
        "permisos": ["gestionar_usuarios", "gestionar_catalogo_inventario", "crear_material", "registrar_entrada", "registrar_salida", "ajustar_inventario", "solicitar_material", "aprobar_solicitud", "ver_reportes_globales", "ver_mi_historial", "ver_mis_reportes"]
    },
    {
        "nombre": "GestorInventario",
        "descripcion": "Encargado de gestión física e ingreso/salida de materiales",
        "es_superadmin": False,
        "es_de_fabrica": True,
        "permisos": ["gestionar_catalogo_inventario", "crear_material", "registrar_entrada", "registrar_salida", "ajustar_inventario", "solicitar_material", "aprobar_solicitud", "ver_mi_historial", "ver_mis_reportes"]
    },
    {
        "nombre": "Doctor",
        "descripcion": "Personal médico autorizados para registrar salidas y solicitudes de material",
        "es_superadmin": False,
        "es_de_fabrica": True,
        "permisos": ["registrar_salida", "solicitar_material", "ver_mi_historial", "ver_mis_reportes"]
    }
]

def cargar_seeds_roles_y_permisos():
    """Crea los permisos base y los roles de fábrica iniciales."""
    permisos_dict = {}
    for data in PERMISOS_BASE:
        perm, _ = Permiso.objects.get_or_create(
            codigo=data["codigo"],
            defaults={"nombre": data["nombre"], "descripcion": data["descripcion"]}
        )
        permisos_dict[data["codigo"]] = perm

    for r_data in ROLES_FABRICA:
        rol, _ = Rol.objects.get_or_create(
            nombre=r_data["nombre"],
            defaults={
                "descripcion": r_data["descripcion"],
                "es_superadmin": r_data["es_superadmin"],
                "es_de_fabrica": r_data["es_de_fabrica"]
            }
        )
        # Asignar permisos al rol
        for cod_permiso in r_data["permisos"]:
            if cod_permiso in permisos_dict:
                RolPermiso.objects.get_or_create(rol=rol, permiso=permisos_dict[cod_permiso])

    return True
