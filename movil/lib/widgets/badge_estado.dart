import 'package:flutter/material.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class BadgeEstado extends StatelessWidget {
  final String estado;

  const BadgeEstado({
    super.key,
    required this.estado,
  });

  Color _getColor() {
    switch (estado.toLowerCase()) {
      case 'aprobada':
      case 'exitoso':
      case 'activo':
        return CeosColors.statusSuccess;
      case 'pendiente':
      case 'en_proceso':
        return CeosColors.statusWarning;
      case 'rechazada':
      case 'fallido':
      case 'inactivo':
      case 'cancelada':
        return CeosColors.statusDanger;
      default:
        return CeosColors.lightTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        estado.toUpperCase(),
        style: CeosTheme.dataMono(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
