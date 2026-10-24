import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/constants/icon_catalog.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class SelectorIconoGrid extends StatefulWidget {
  final String? iconoSeleccionado;
  final ValueChanged<String> onIconSelected;

  final double? gridHeight;

  const SelectorIconoGrid({
    super.key,
    this.iconoSeleccionado,
    required this.onIconSelected,
    this.gridHeight,
  });

  @override
  State<SelectorIconoGrid> createState() => _SelectorIconoGridState();
}

class _SelectorIconoGridState extends State<SelectorIconoGrid> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredIcons = IconCatalog.availableIconNames;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredIcons = IconCatalog.searchIcons(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool hasBoundedHeight = constraints.hasBoundedHeight;

        final Widget gridContent = _filteredIcons.isEmpty
            ? Center(
                child: Text(
                  'No se encontraron íconos',
                  style: CeosTheme.body(color: CeosColors.lightTextMuted),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _filteredIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _filteredIcons[index];
                  final isSelected = widget.iconoSeleccionado == iconName;
                  final iconData = IconCatalog.getIcon(iconName);

                  return InkWell(
                    onTap: () => widget.onIconSelected(iconName),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CeosColors.areaOdontologia.withValues(alpha: 0.15)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? CeosColors.areaOdontologia
                              : Colors.grey.withValues(alpha: 0.25),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            iconData,
                            size: 24,
                            color: isSelected
                                ? CeosColors.areaOdontologia
                                : CeosColors.lightTextPrimary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            iconName,
                            style: CeosTheme.dataMono(
                              fontSize: 9,
                              color: isSelected
                                  ? CeosColors.areaOdontologia
                                  : CeosColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );

        return Column(
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Buscar ícono (ej. labios, farmacia, diente, jeringa)...',
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (hasBoundedHeight)
              Expanded(child: gridContent)
            else
              SizedBox(
                height: widget.gridHeight ?? 320,
                child: gridContent,
              ),
          ],
        );
      },
    );
  }
}
