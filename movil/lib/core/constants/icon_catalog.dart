import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class IconCatalog {
  IconCatalog._();

  static const String fallbackIconName = 'package';

  /// Catálogo principal de íconos disponibles para áreas, categorías y materiales
  static const Map<String, IconData> _icons = {
    // --- ESTÉTICA FACIAL & BELLEZA ---
    'lips': Symbols.lips_rounded,
    'face_retouching': Symbols.face_retouching_natural_rounded,
    'spa': Symbols.spa_rounded,
    'dermatology': Symbols.dermatology_rounded,
    'flower_lotus': PhosphorIconsRegular.flowerLotus,
    'flower': PhosphorIconsRegular.flower,
    'leaf': PhosphorIconsRegular.leaf,
    'sparkle': PhosphorIconsRegular.sparkle,
    'star': PhosphorIconsRegular.starFour,
    'diamond': PhosphorIconsRegular.diamond,
    'magic_wand': PhosphorIconsRegular.magicWand,
    'paint_brush': PhosphorIconsRegular.paintBrush,
    'mask_happy': PhosphorIconsRegular.maskHappy,
    'face_mask': PhosphorIconsRegular.faceMask,
    'eye': PhosphorIconsRegular.eye,
    'crown': PhosphorIconsRegular.crown,

    // --- ODONTOLOGÍA ---
    'tooth': PhosphorIconsRegular.tooth,
    'dentistry': Symbols.dentistry_rounded,
    'bone': PhosphorIconsRegular.bone,

    // --- MEDICINA & FARMACIA ---
    'pill': PhosphorIconsRegular.pill,
    'syringe': PhosphorIconsRegular.syringe,
    'needle': PhosphorIconsRegular.needle,
    'prescription': Symbols.prescriptions_rounded,
    'local_pharmacy': Symbols.local_pharmacy_rounded,
    'medication': Symbols.medication_rounded,
    'medication_liquid': Symbols.medication_liquid_rounded,
    'vaccines': Symbols.vaccines_rounded,
    'medical_services': Symbols.medical_services_rounded,
    'hospital': PhosphorIconsRegular.hospital,
    'first_aid': PhosphorIconsRegular.firstAid,
    'first_aid_kit': PhosphorIconsRegular.firstAidKit,
    'bandaids': PhosphorIconsRegular.bandaids,
    'healing': Symbols.healing_rounded,
    'stethoscope': PhosphorIconsRegular.stethoscope,
    'thermometer': PhosphorIconsRegular.thermometer,
    'heartbeat': PhosphorIconsRegular.heartbeat,
    'blood': Symbols.bloodtype_rounded,
    'fluid_med': Symbols.fluid_med_rounded,
    'sanitizer': Symbols.sanitizer_rounded,
    'hand_soap': PhosphorIconsRegular.handSoap,
    'hand_heart': PhosphorIconsRegular.handHeart,
    'flask': PhosphorIconsRegular.flask,
    'test_tube': PhosphorIconsRegular.testTube,
    'dna': PhosphorIconsRegular.dna,
    'virus': PhosphorIconsRegular.virus,
    'scissors': PhosphorIconsRegular.scissors,
    'drop': PhosphorIconsRegular.drop,
    'eyedropper': PhosphorIconsRegular.eyedropper,
    'spray_bottle': PhosphorIconsRegular.sprayBottle,
    'microscope': PhosphorIconsRegular.microscope,
    'cardiology': Symbols.cardiology_rounded,
    'ecg_heart': Symbols.ecg_heart_rounded,
    'monitor_heart': Symbols.monitor_heart_rounded,
    'pulmonology': Symbols.pulmonology_rounded,
    'oxygen_saturation': Symbols.oxygen_saturation_rounded,
    'neurology': Symbols.neurology_rounded,
    'ophthalmology': Symbols.ophthalmology_rounded,
    'orthopedics': Symbols.orthopedics_rounded,
    'radiology': Symbols.radiology_rounded,
    'surgical': Symbols.surgical_rounded,
    'hematology': Symbols.hematology_rounded,
    'immunology': Symbols.immunology_rounded,
    'biotech': Symbols.biotech_rounded,
    'lab_research': Symbols.lab_research_rounded,
    'clinical_notes': Symbols.clinical_notes_rounded,
    'medical_information': Symbols.medical_information_rounded,
    'health_and_safety': Symbols.health_and_safety_rounded,
    'clean_hands': Symbols.clean_hands_rounded,
    'medical_mask': Symbols.medical_mask_rounded,
    'emergency': Symbols.emergency_rounded,

    // --- GESTIÓN, ALMACÉN & GENERAL ---
    'shield': PhosphorIconsRegular.shieldCheck,
    'shield_plus': PhosphorIconsRegular.shieldPlus,
    'package': PhosphorIconsRegular.package,
    'cube': PhosphorIconsRegular.cube,
    'archive': PhosphorIconsRegular.archive,
    'stack': PhosphorIconsRegular.stack,
    'tray': PhosphorIconsRegular.tray,
    'folder': PhosphorIconsRegular.folder,
    'tag': PhosphorIconsRegular.tag,
    'scales': PhosphorIconsRegular.scales,
    'gear': PhosphorIconsRegular.gear,
    'users': PhosphorIconsRegular.users,
    'chart_bar': PhosphorIconsRegular.chartBar,
    'database': PhosphorIconsRegular.database,
    'bell': PhosphorIconsRegular.bell,
    'calendar': PhosphorIconsRegular.calendar,
    'clock': PhosphorIconsRegular.clock,
    'file_pdf': PhosphorIconsRegular.filePdf,
    'clipboard_text': PhosphorIconsRegular.clipboardText,
    'barcode': PhosphorIconsRegular.barcode,
    'qr_code': PhosphorIconsRegular.qrCode,
    'bed': PhosphorIconsRegular.bed,
  };

  /// Etiquetas visibles en español para mostrar en la interfaz de selección
  static const Map<String, String> _labelsEs = {
    // Estética Facial & Belleza
    'lips': 'Labios',
    'face_retouching': 'Estética facial',
    'spa': 'Spa',
    'dermatology': 'Dermatología',
    'flower_lotus': 'Loto',
    'flower': 'Flor',
    'leaf': 'Natural',
    'sparkle': 'Brillo',
    'star': 'Estrella',
    'diamond': 'Diamante',
    'magic_wand': 'Tratamiento',
    'paint_brush': 'Pincel',
    'mask_happy': 'Mascarilla',
    'face_mask': 'Cuidado facial',
    'eye': 'Ojo / Mirada',
    'crown': 'Premium',

    // Odontología
    'tooth': 'Diente',
    'dentistry': 'Odontología',
    'bone': 'Hueso',

    // Medicina & Farmacia
    'pill': 'Pastilla',
    'syringe': 'Jeringa',
    'needle': 'Aguja',
    'prescription': 'Receta',
    'local_pharmacy': 'Farmacia',
    'medication': 'Medicamento',
    'medication_liquid': 'Jarabe',
    'vaccines': 'Vacuna',
    'medical_services': 'Maletín médico',
    'hospital': 'Clínica',
    'first_aid': 'Auxilios',
    'first_aid_kit': 'Botiquín',
    'bandaids': 'Curitas',
    'healing': 'Curación',
    'stethoscope': 'Estetoscopio',
    'thermometer': 'Termómetro',
    'heartbeat': 'Signos vitales',
    'blood': 'Sangre',
    'fluid_med': 'Suero IV',
    'sanitizer': 'Desinfectante',
    'hand_soap': 'Jabón',
    'hand_heart': 'Cuidado',
    'flask': 'Matraz',
    'test_tube': 'Tubo ensayo',
    'dna': 'Genética',
    'virus': 'Virus',
    'scissors': 'Tijeras',
    'drop': 'Gota',
    'eyedropper': 'Gotero',
    'spray_bottle': 'Atomizador',
    'microscope': 'Microscopio',
    'cardiology': 'Cardiología',
    'ecg_heart': 'Electrocardiograma',
    'monitor_heart': 'Monitor cardíaco',
    'pulmonology': 'Pulmones',
    'oxygen_saturation': 'Oxímetro',
    'neurology': 'Neurología',
    'ophthalmology': 'Oftalmología',
    'orthopedics': 'Ortopedia',
    'radiology': 'Radiología',
    'surgical': 'Cirugía',
    'hematology': 'Hematología',
    'immunology': 'Inmunología',
    'biotech': 'Biotecnología',
    'lab_research': 'Laboratorio',
    'clinical_notes': 'Historia clínica',
    'medical_information': 'Ficha médica',
    'health_and_safety': 'Bioseguridad',
    'clean_hands': 'Higiene manos',
    'medical_mask': 'Barbijo',
    'emergency': 'Emergencia',

    // Gestión & Almacén
    'shield': 'Seguridad',
    'shield_plus': 'Protección',
    'package': 'Paquete',
    'cube': 'Caja',
    'archive': 'Archivo',
    'stack': 'Lotes',
    'tray': 'Bandeja',
    'folder': 'Carpeta',
    'tag': 'Etiqueta',
    'scales': 'Balanza',
    'gear': 'Ajustes',
    'users': 'Personal',
    'chart_bar': 'Reportes',
    'database': 'Base datos',
    'bell': 'Alertas',
    'calendar': 'Calendario',
    'clock': 'Horario',
    'file_pdf': 'Documento PDF',
    'clipboard_text': 'Formulario',
    'barcode': 'Cód. barras',
    'qr_code': 'Código QR',
    'bed': 'Camilla',
  };

  /// Aliases en español y términos equivalentes para búsqueda y resolución flexible
  static const Map<String, String> _aliases = {
    // Labios y estética
    'labios': 'lips',
    'boca': 'lips',
    'estetica': 'dermatology',
    'estetica_facial': 'face_retouching',
    'facial': 'face_retouching',
    'dermatologia': 'dermatology',
    'piel': 'dermatology',
    'belleza': 'spa',
    'botox': 'needle',
    'relleno': 'lips',
    'acido_hialuronico': 'lips',
    'loto': 'flower_lotus',
    'diamante': 'diamond',
    'brillo': 'sparkle',
    'mirada': 'eye',
    'pincel': 'paint_brush',
    'mascarilla': 'face_mask',

    // Odontología
    'diente': 'tooth',
    'dientes': 'tooth',
    'odontologia': 'dentistry',
    'ortodoncia': 'tooth',
    'muela': 'tooth',
    'hueso': 'bone',

    // Farmacia y medicina
    'farmacia': 'local_pharmacy',
    'medicina': 'medication',
    'medicamento': 'medication',
    'pastilla': 'pill',
    'comprimido': 'pill',
    'capsula': 'pill',
    'jarabe': 'medication_liquid',
    'gotas': 'medication_liquid',
    'jeringa': 'syringe',
    'inyeccion': 'syringe',
    'aguja': 'needle',
    'receta': 'prescription',
    'prescripcion': 'prescription',
    'vacuna': 'vaccines',
    'vacunas': 'vaccines',
    'suero': 'fluid_med',
    'sangre': 'blood',
    'botiquin': 'first_aid_kit',
    'curitas': 'bandaids',
    'curita': 'bandaids',
    'band_aids': 'bandaids',
    'curacion': 'healing',
    'estetoscopio': 'stethoscope',
    'termometro': 'thermometer',
    'corazon': 'heartbeat',
    'clinica': 'hospital',
    'desinfectante': 'sanitizer',
    'alcohol': 'sanitizer',
    'jabon': 'hand_soap',
    'tubo': 'test_tube',
    'matraz': 'flask',
    'gotero': 'eyedropper',
    'tijeras': 'scissors',
    'spray': 'spray_bottle',
    'cardiologia': 'cardiology',
    'electrocardiograma': 'ecg_heart',
    'monitor': 'monitor_heart',
    'pulmones': 'pulmonology',
    'neumologia': 'pulmonology',
    'oxigeno': 'oxygen_saturation',
    'oximetro': 'oxygen_saturation',
    'neurologia': 'neurology',
    'oftalmologia': 'ophthalmology',
    'ortopedia': 'orthopedics',
    'traumatologia': 'orthopedics',
    'radiologia': 'radiology',
    'rayos_x': 'radiology',
    'cirugia': 'surgical',
    'bisturi': 'surgical',
    'hematologia': 'hematology',
    'inmunologia': 'immunology',
    'laboratorio': 'lab_research',
    'microscopio': 'microscope',
    'historia_clinica': 'clinical_notes',
    'ficha_medica': 'medical_information',
    'bioseguridad': 'health_and_safety',
    'higiene': 'clean_hands',
    'barbijo': 'medical_mask',
    'emergencia': 'emergency',
    'urgencia': 'emergency',
    'camilla': 'bed',
  };

  static List<String> get availableIconNames => _icons.keys.toList();

  static String getLabelEs(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return _labelsEs[fallbackIconName] ?? fallbackIconName;
    }
    final key = iconName.toLowerCase().trim();
    if (_labelsEs.containsKey(key)) {
      return _labelsEs[key]!;
    }
    final target = _aliases[key];
    if (target != null && _labelsEs.containsKey(target)) {
      return _labelsEs[target]!;
    }
    return key.replaceAll('_', ' ');
  }

  static String _normalizeForSearch(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  static IconData getIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return PhosphorIconsRegular.package;
    }
    final key = iconName.toLowerCase().trim();
    if (_icons.containsKey(key)) {
      return _icons[key]!;
    }
    final target = _aliases[key];
    if (target != null && _icons.containsKey(target)) {
      return _icons[target]!;
    }
    return PhosphorIconsRegular.package;
  }

  static List<String> searchIcons(String query) {
    if (query.trim().isEmpty) {
      return availableIconNames;
    }
    final normalized = _normalizeForSearch(query);
    final results = <String>{};

    // Coincidencia directa en nombres canónicos
    for (final name in _icons.keys) {
      if (_normalizeForSearch(name).contains(normalized)) {
        results.add(name);
      }
    }

    // Coincidencia en etiquetas visibles en español
    for (final entry in _labelsEs.entries) {
      if (_normalizeForSearch(entry.value).contains(normalized)) {
        if (_icons.containsKey(entry.key)) {
          results.add(entry.key);
        }
      }
    }

    // Coincidencia en alias (ej. busca 'labios' -> agrega 'lips')
    for (final entry in _aliases.entries) {
      final normAlias = _normalizeForSearch(entry.key);
      if (normAlias.contains(normalized) || normalized.contains(normAlias)) {
        if (_icons.containsKey(entry.value)) {
          results.add(entry.value);
        }
      }
    }

    return results.toList();
  }
}

