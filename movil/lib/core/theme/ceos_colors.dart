import 'package:flutter/material.dart';

class CeosColors {
  CeosColors._();

  // --- Áreas Temáticas ---
  static const Color primary = Color(0xFF0891B2); // Alias primario institucional
  static const Color areaOdontologia = Color(0xFF0891B2); // Cyan / Teal Dental
  static const Color areaOdontologiaLight = Color(0xFFE0F2FE);
  static const Color areaOdontologiaDark = Color(0xFF155E75);

  static const Color areaEstetica = Color(0xFFDB2777); // Rose / Pink Estética
  static const Color areaEsteticaLight = Color(0xFFFCE7F3);
  static const Color areaEsteticaDark = Color(0xFF9D174D);

  // --- Estados de Inventario & Alertas ---
  static const Color statusSuccess = Color(0xFF10B981); // Verde - Stock OK / Normal
  static const Color statusSuccessLight = Color(0xFFECFDF5);
  static const Color statusWarning = Color(0xFFF59E0B); // Ámbar - Próximo a vencer / Alerta
  static const Color statusWarningLight = Color(0xFFFFFBEB);
  static const Color statusDanger = Color(0xFFEF4444); // Coral / Rojo - Stock bajo / Crítico / Error
  static const Color statusDangerLight = Color(0xFFFEF2F2);
  static const Color statusInfo = Color(0xFF3B82F6); // Azul informativo
  static const Color statusInfoLight = Color(0xFFEFF6FF);

  // --- Roles ---
  static const Color roleSuperadmin = Color(0xFF8B5CF6); // Púrpura
  static const Color roleAdmin = Color(0xFF3B82F6); // Azul
  static const Color roleDoctor = Color(0xFF0891B2); // Cyan
  static const Color roleGestor = Color(0xFF10B981); // Esmeralda
  static const Color roleDefault = Color(0xFF6B7280); // Gris

  // --- Neutrales Modo Claro ---
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // --- Neutrales Modo Oscuro Premium (Midnight Sapphire) ---
  static const Color darkBackground = Color(0xFF070B14); // Ultra-deep midnight slate
  static const Color darkSurface = Color(0xFF0D1527); // Rich dark navy surface
  static const Color darkCard = Color(0xFF131D31); // Elevated deep navy card
  static const Color darkBorder = Color(0xFF1E2D4A); // Defined navy border
  static const Color darkCardBorder = Color(0x2238BDF8); // Subtle cyan luminous edge
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Crisp white
  static const Color darkTextSecondary = Color(0xFF94A3B8); // High-contrast slate
  static const Color darkTextMuted = Color(0xFF64748B); // Muted slate

  // --- Resplandores Ambientales (Ambient Glows) ---
  static const Color ambientCyan = Color(0xFF0891B2);
  static const Color ambientTeal = Color(0xFF0D9488);
  static const Color ambientPurple = Color(0xFF7C3AED);
  static const Color ambientRose = Color(0xFFDB2777);
  static const Color ambientBlue = Color(0xFF2563EB);
}

/// Extensión de conveniencia para acceder reactivamente a los tokens del tema
/// según el modo actual (Claro u Oscuro).
extension CeosThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get textPrimary =>
      isDarkMode ? CeosColors.darkTextPrimary : CeosColors.lightTextPrimary;

  Color get textSecondary =>
      isDarkMode ? CeosColors.darkTextSecondary : CeosColors.lightTextSecondary;

  Color get textMuted =>
      isDarkMode ? CeosColors.darkTextMuted : CeosColors.lightTextMuted;

  Color get cardBg =>
      isDarkMode ? CeosColors.darkCard : CeosColors.lightCard;

  Color get surfaceBg =>
      isDarkMode ? CeosColors.darkSurface : CeosColors.lightSurface;

  Color get borderColor =>
      isDarkMode ? CeosColors.darkBorder : CeosColors.lightBorder;

  Color get cardBorderColor =>
      isDarkMode ? CeosColors.darkCardBorder : CeosColors.lightCardBorder;
}

