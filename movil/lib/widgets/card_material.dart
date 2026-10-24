import 'package:flutter/material.dart';
import '../core/constants/icon_catalog.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class CardMaterial extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const CardMaterial({
    super.key,
    required this.material,
    required this.onTap,
  });

  Color _getRibbonColor() {
    switch (material.estadoRibbon) {
      case EstadoRibbon.critico:
        return CeosColors.statusDanger;
      case EstadoRibbon.advertencia:
        return CeosColors.statusWarning;
      case EstadoRibbon.normal:
        return CeosColors.statusSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ribbonColor = _getRibbonColor();
    final icon = IconCatalog.getIcon(material.categoriaIcono);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
              color: ribbonColor.withValues(alpha: isDark ? 0.08 : 0.03),
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
                // Ribbon lateral de estado con gradiente sutil
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: ribbonColor,
                    boxShadow: [
                      BoxShadow(
                        color: ribbonColor.withValues(alpha: 0.4),
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
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isDark
                                ? CeosColors.areaOdontologia.withValues(alpha: 0.16)
                                : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: CeosColors.areaOdontologia,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                material.nombre,
                                style: CeosTheme.heading(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CeosColors.areaOdontologia.withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 11,
                                          color: CeosColors.areaOdontologia,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          material.categoriaNombre.isNotEmpty
                                              ? material.categoriaNombre
                                              : 'Sin categoría',
                                          style: CeosTheme.body(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: CeosColors.areaOdontologia,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (material.areaNombre.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.07)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        material.areaNombre,
                                        style: CeosTheme.dataMono(
                                          fontSize: 10,
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${material.stockTotal}',
                              style: CeosTheme.dataMono(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ribbonColor,
                              ),
                            ),
                            Text(
                              material.unidadMedida,
                              style: CeosTheme.body(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          ],
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
