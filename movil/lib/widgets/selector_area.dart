import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/constants/icon_catalog.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';
import '../providers/inventario_providers.dart';

class SelectorArea extends ConsumerWidget {
  final ValueChanged<AreaModel>? onAreaSelected;
  final bool showHeader;
  final bool navegarAlSeleccionar;

  const SelectorArea({
    super.key,
    this.onAreaSelected,
    this.showHeader = true,
    this.navegarAlSeleccionar = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProvider);
    final areaSeleccionada = ref.watch(areaSeleccionadaProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selecciona el Área',
                style: CeosTheme.heading(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (areaSeleccionada != null)
                TextButton(
                  onPressed: () {
                    ref.read(areaSeleccionadaProvider.notifier).state = null;
                    ref.read(filtroMaterialesProvider.notifier).state = const FiltroMateriales();
                  },
                  child: Text(
                    'Ver todas',
                    style: CeosTheme.body(fontSize: 12, color: CeosColors.areaOdontologia, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        areasAsync.when(
          data: (areas) {
            if (areas.isEmpty) {
              return Text(
                'No hay áreas configuradas.',
                style: CeosTheme.body(color: CeosColors.lightTextMuted),
              );
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Row(
              children: areas.map((area) {
                final isSelected = areaSeleccionada?.id == area.id;
                final isOdonto = area.esOdontologia;
                final baseColor = isOdonto ? CeosColors.areaOdontologia : CeosColors.areaEstetica;
                final lightBg = isDark
                    ? baseColor.withValues(alpha: 0.2)
                    : (isOdonto ? CeosColors.areaOdontologiaLight : CeosColors.areaEsteticaLight);
                final icon = IconCatalog.getIcon(area.icono.isNotEmpty ? area.icono : (isOdonto ? 'tooth' : 'sparkle'));

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        if (isSelected) {
                          ref.read(areaSeleccionadaProvider.notifier).state = null;
                          ref.read(filtroMaterialesProvider.notifier).state = const FiltroMateriales();
                        } else {
                          ref.read(areaSeleccionadaProvider.notifier).state = area;
                          ref.read(filtroMaterialesProvider.notifier).state =
                              FiltroMateriales(areaId: area.id);
                          onAreaSelected?.call(area);
                          if (navegarAlSeleccionar && context.mounted) {
                            context.push('/inventario');
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? baseColor.withValues(alpha: isDark ? 0.2 : 0.12)
                              : (isDark
                                  ? CeosColors.darkCard.withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.95)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? baseColor
                                : (isDark ? CeosColors.darkCardBorder : CeosColors.lightBorder),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                            if (isSelected)
                              BoxShadow(
                                color: baseColor.withValues(alpha: isDark ? 0.25 : 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lightBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, size: 20, color: baseColor),
                                ),
                                if (isSelected)
                                  Icon(
                                    PhosphorIconsFill.checkCircle,
                                    color: baseColor,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              area.nombre,
                              style: CeosTheme.heading(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? baseColor : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${area.cantidadMateriales} materiales',
                              style: CeosTheme.dataMono(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => Row(
            children: [
              Expanded(
                child: Container(
                  height: 95,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 95,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CeosColors.statusDangerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CeosColors.statusDanger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.warningCircle, color: CeosColors.statusDanger, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No se pudieron cargar las áreas.',
                    style: CeosTheme.body(fontSize: 13, color: CeosColors.statusDanger, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.refresh(areasProvider),
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 14),
                  label: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
