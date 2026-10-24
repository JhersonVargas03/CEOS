import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class TarjetaAlerta extends StatelessWidget {
  final AlertaInventarioModel alerta;
  final VoidCallback onTap;

  const TarjetaAlerta({
    super.key,
    required this.alerta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = alerta.esCritica ? CeosColors.statusDanger : CeosColors.statusWarning;
    final iconBgColor = isDark
        ? color.withValues(alpha: 0.2)
        : (alerta.esCritica ? CeosColors.statusDangerLight : CeosColors.statusWarningLight);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? CeosColors.darkCard.withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? CeosColors.darkCardBorder : CeosColors.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja lateral de severidad con sutil glow
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            alerta.esCritica
                                ? PhosphorIconsFill.warningCircle
                                : PhosphorIconsFill.clockCountdown,
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                alerta.titulo,
                                style: CeosTheme.heading(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alerta.mensaje,
                                style: CeosTheme.body(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          PhosphorIconsRegular.caretRight,
                          size: 16,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
