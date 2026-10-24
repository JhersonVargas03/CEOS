import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/constants/icon_catalog.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class SelectorAreaModal extends StatefulWidget {
  final List<AreaModel> areas;
  final int? areaSeleccionadaId;
  final String titulo;

  const SelectorAreaModal({
    super.key,
    required this.areas,
    this.areaSeleccionadaId,
    this.titulo = 'Seleccionar Área',
  });

  static Future<AreaModel?> show({
    required BuildContext context,
    required List<AreaModel> areas,
    int? areaSeleccionadaId,
    String titulo = 'Seleccionar Área',
  }) {
    return showModalBottomSheet<AreaModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectorAreaModal(
        areas: areas,
        areaSeleccionadaId: areaSeleccionadaId,
        titulo: titulo,
      ),
    );
  }

  @override
  State<SelectorAreaModal> createState() => _SelectorAreaModalState();
}

class _SelectorAreaModalState extends State<SelectorAreaModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filtro = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtro.isEmpty
        ? widget.areas
        : widget.areas.where((a) {
            return a.nombre.toLowerCase().contains(_filtro) ||
                a.descripcion.toLowerCase().contains(_filtro);
          }).toList();

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.top - 24;
    final modalHeight = (mediaQuery.size.height * 0.65).clamp(240.0, availableHeight > 240 ? availableHeight : 240.0);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
        height: modalHeight,
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.buildings, size: 24, color: CeosColors.areaOdontologia),
                  const SizedBox(width: 10),
                  Text(
                    widget.titulo,
                    style: CeosTheme.heading(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (widget.areas.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar área...',
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: context.isDarkMode ? CeosColors.darkSurface : CeosColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: filtradas.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron áreas',
                        style: CeosTheme.body(color: context.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtradas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                      itemBuilder: (context, i) {
                        final a = filtradas[i];
                        final isSelected = a.id == widget.areaSeleccionadaId;
                        final isOdonto = a.esOdontologia;
                        final areaColor = isOdonto ? CeosColors.areaOdontologia : CeosColors.areaEstetica;
                        final icon = IconCatalog.getIcon(
                          a.icono.isNotEmpty ? a.icono : (isOdonto ? 'tooth' : 'sparkle'),
                        );

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: areaColor.withValues(alpha: 0.14),
                            child: Icon(
                              icon,
                              color: areaColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            a.nombre,
                            style: CeosTheme.heading(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? areaColor : null,
                            ),
                          ),
                          subtitle: a.descripcion.isNotEmpty
                              ? Text(
                                  a.descripcion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CeosTheme.body(fontSize: 12, color: context.textSecondary),
                                )
                              : null,
                          trailing: isSelected
                              ? Icon(PhosphorIconsRegular.checkCircle, color: areaColor, size: 22)
                              : Icon(PhosphorIconsRegular.caretRight, size: 16, color: context.textSecondary),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
