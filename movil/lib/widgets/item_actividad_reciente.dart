import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class ItemActividadReciente extends StatelessWidget {
  final MovimientoHistorialModel movimiento;

  const ItemActividadReciente({
    super.key,
    required this.movimiento,
  });

  IconData _getIcon() {
    switch (movimiento.tipo.toLowerCase()) {
      case 'entrada':
        return PhosphorIconsRegular.arrowSquareIn;
      case 'salida':
        return PhosphorIconsRegular.arrowSquareOut;
      case 'ajuste':
        return PhosphorIconsRegular.slidersHorizontal;
      default:
        return PhosphorIconsRegular.clock;
    }
  }

  Color _getColor() {
    switch (movimiento.tipo.toLowerCase()) {
      case 'entrada':
        return CeosColors.statusSuccess;
      case 'salida':
        return CeosColors.areaOdontologia;
      case 'ajuste':
        return CeosColors.statusWarning;
      default:
        return CeosColors.lightTextSecondary;
    }
  }

  String _formatFecha(String fechaStr) {
    if (fechaStr.isEmpty) return 'Reciente';
    try {
      final date = DateTime.parse(fechaStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) {
        return 'Hace ${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return 'Hace ${diff.inHours}h';
      } else {
        return 'Hace ${diff.inDays}d';
      }
    } catch (_) {
      return fechaStr.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${movimiento.tipo.toUpperCase()} — ${movimiento.cantidad} unidades',
                  style: CeosTheme.heading(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((movimiento.motivo != null && movimiento.motivo!.isNotEmpty) ||
                    (movimiento.loteCodigo != null && movimiento.loteCodigo!.isNotEmpty))
                  Text(
                    [
                      if (movimiento.loteCodigo != null && movimiento.loteCodigo!.isNotEmpty)
                        'Lote: ${movimiento.loteCodigo}',
                      if (movimiento.motivo != null && movimiento.motivo!.isNotEmpty)
                        movimiento.motivo!,
                    ].join(' • '),
                    style: CeosTheme.body(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _formatFecha(movimiento.fecha),
            style: CeosTheme.dataMono(
              fontSize: 11,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
