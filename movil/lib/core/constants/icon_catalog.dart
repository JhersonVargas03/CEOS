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

    // --- GESTIÓN, ALMACÉN & GENERAL ---
    'shield': PhosphorIconsRegular.shieldCheck,
    'package': PhosphorIconsRegular.package,
    'cube': PhosphorIconsRegular.cube,
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
  };

  static List<String> get availableIconNames => _icons.keys.toList();

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
    final normalized = query.toLowerCase().trim();
    final results = <String>{};

    // Coincidencia directa en nombres canónicos
    for (final name in _icons.keys) {
      if (name.contains(normalized)) {
        results.add(name);
      }
    }

    // Coincidencia en alias (ej. busca 'labios' -> agrega 'lips')
    for (final entry in _aliases.entries) {
      if (entry.key.contains(normalized) || normalized.contains(entry.key)) {
        if (_icons.containsKey(entry.value)) {
          results.add(entry.value);
        }
      }
    }

    return results.toList();
  }
}

