import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/constants/icon_catalog.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class ChipsCategoria extends StatelessWidget {
  final List<CategoriaModel> categorias;
  final int? categoriaSeleccionadaId;
  final ValueChanged<int?> onCategoriaSelected;

  const ChipsCategoria({
    super.key,
    required this.categorias,
    required this.categoriaSeleccionadaId,
    required this.onCategoriaSelected,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedTextColor = context.textPrimary;
    final unselectedIconColor = context.textSecondary;
    final chipBgColor = context.cardBg;
    final chipBorderColor = context.borderColor;

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Chip "Todas"
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                'Todas',
                style: CeosTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: categoriaSeleccionadaId == null
                      ? Colors.white
                      : unselectedTextColor,
                ),
              ),
              avatar: Icon(
                PhosphorIconsRegular.squaresFour,
                size: 16,
                color: categoriaSeleccionadaId == null
                    ? Colors.white
                    : unselectedIconColor,
              ),
              selected: categoriaSeleccionadaId == null,
              selectedColor: CeosColors.areaOdontologia,
              backgroundColor: chipBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: categoriaSeleccionadaId == null
                      ? CeosColors.areaOdontologia
                      : chipBorderColor,
                ),
              ),
              showCheckmark: false,
              onSelected: (_) => onCategoriaSelected(null),
            ),
          ),
          ...categorias.map((cat) {
            final isSelected = categoriaSeleccionadaId == cat.id;
            final icon = IconCatalog.getIcon(cat.icono);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  cat.nombre,
                  style: CeosTheme.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : unselectedTextColor,
                  ),
                ),
                avatar: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : unselectedIconColor,
                ),
                selected: isSelected,
                selectedColor: CeosColors.areaOdontologia,
                backgroundColor: chipBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? CeosColors.areaOdontologia
                        : chipBorderColor,
                  ),
                ),
                showCheckmark: false,
                onSelected: (_) => onCategoriaSelected(isSelected ? null : cat.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}
