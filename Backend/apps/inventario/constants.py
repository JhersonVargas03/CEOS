# T-304.4 / T-AJUSTE-MV.20 / T-AJUSTE-MV.21: Catálogo de íconos válidos para Área y CategoriaMaterial.
# Identificadores alineados con el catálogo de phosphor_flutter y material_symbols_icons en el frontend.

ICONOS_DISPONIBLES = [
    # Genérico / Almacén / Gestión
    "package",
    "cube",
    "archive",
    "box",
    "stack",
    "tray",
    "folder",
    "tag",
    "scales",
    "gear",
    "users",
    "chart_bar",
    "database",
    "bell",
    "calendar",
    "clock",
    "file_pdf",
    "shield",
    "shield_plus",

    # Estética Facial & Belleza
    "lips",
    "face_retouching",
    "spa",
    "dermatology",
    "flower_lotus",
    "flower",
    "leaf",
    "sparkle",
    "star",
    "diamond",
    "magic_wand",
    "paint_brush",
    "mask_happy",
    "face_mask",
    "eye",
    "crown",

    # Odontología
    "tooth",
    "tooth_outline",
    "dentistry",
    "bone",

    # Medicina & Farmacia
    "pill",
    "pills",
    "syringe",
    "needle",
    "prescription",
    "local_pharmacy",
    "medication",
    "medication_liquid",
    "vaccines",
    "medical_services",
    "hospital",
    "first_aid",
    "first_aid_kit",
    "bandaids",
    "healing",
    "stethoscope",
    "thermometer",
    "heartbeat",
    "heart_pulse",
    "blood",
    "fluid_med",
    "sanitizer",
    "hand_soap",
    "hand_heart",
    "flask",
    "test_tube",
    "dna",
    "virus",
    "bacteria",
    "scissors",
    "drop",
    "eyedropper",
    "spray_bottle",
    "microscope",
    "hand",

    # Operaciones & Mobiliario / Materiales físicos
    "clipboard",
    "clipboard_text",
    "list_checks",
    "barcode",
    "qr_code",
    "wrench",
    "recycle",
    "arrow_square_in",
    "arrow_square_out",
    "gloves",
    "mask",
    "bed",
    "lamp",
    "trolley",
    "chair",
]

# Mapa de sinónimos y términos en español a su identificador canónico
MAPA_ALIAS_ICONOS = {
    # Labios y estética
    "labios": "lips",
    "boca": "lips",
    "estetica": "dermatology",
    "estetica_facial": "face_retouching",
    "facial": "face_retouching",
    "dermatologia": "dermatology",
    "piel": "dermatology",
    "belleza": "spa",
    "botox": "needle",
    "relleno": "lips",
    "acido_hialuronico": "lips",
    "loto": "flower_lotus",
    "diamante": "diamond",
    "brillo": "sparkle",
    "mirada": "eye",
    "pincel": "paint_brush",
    "mascarilla": "face_mask",

    # Odontología
    "diente": "tooth",
    "dientes": "tooth",
    "odontologia": "dentistry",
    "ortodoncia": "tooth",
    "muela": "tooth",
    "hueso": "bone",

    # Farmacia y medicina
    "farmacia": "local_pharmacy",
    "medicina": "medication",
    "medicamento": "medication",
    "pastilla": "pill",
    "comprimido": "pill",
    "capsula": "pill",
    "jarabe": "medication_liquid",
    "gotas": "medication_liquid",
    "jeringa": "syringe",
    "inyeccion": "syringe",
    "aguja": "needle",
    "receta": "prescription",
    "prescripcion": "prescription",
    "vacuna": "vaccines",
    "vacunas": "vaccines",
    "suero": "fluid_med",
    "sangre": "blood",
    "botiquin": "first_aid_kit",
    "curitas": "bandaids",
    "curita": "bandaids",
    "band_aids": "bandaids",
    "curacion": "healing",
    "estetoscopio": "stethoscope",
    "termometro": "thermometer",
    "corazon": "heartbeat",
    "clinica": "hospital",
    "desinfectante": "sanitizer",
    "alcohol": "sanitizer",
    "jabon": "hand_soap",
    "tubo": "test_tube",
    "matraz": "flask",
    "gotero": "eyedropper",
    "tijeras": "scissors",
    "spray": "spray_bottle",
}

# Set para validación O(1)
ICONOS_DISPONIBLES_SET = set(ICONOS_DISPONIBLES)


def normalizar_icono(identificador: str) -> str:
    """Normaliza un identificador de ícono (minúsculas, strip y mapeo de alias)."""
    if not identificador or not isinstance(identificador, str):
        return ""
    key = identificador.strip().lower()
    return MAPA_ALIAS_ICONOS.get(key, key)


def es_icono_valido(identificador: str) -> bool:
    """T-304.7 / T-AJUSTE-MV.21: Retorna True si el identificador (o su alias) está dentro del catálogo permitido."""
    return normalizar_icono(identificador) in ICONOS_DISPONIBLES_SET
