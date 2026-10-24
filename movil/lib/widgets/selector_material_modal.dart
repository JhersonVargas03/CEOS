import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../models/inventario_models.dart';

class SelectorMaterialModal extends StatefulWidget {
  final List<MaterialModel> materiales;
  final String titulo;
  final bool soloConStock;
  final int? areaId;
  final VoidCallback? onCrearNuevo;

  const SelectorMaterialModal({
    super.key,
    required this.materiales,
    this.titulo = 'Seleccionar Material',
    this.soloConStock = false,
    this.areaId,
    this.onCrearNuevo,
  });

  static Future<MaterialModel?> show({
    required BuildContext context,
    required List<MaterialModel> materiales,
    String titulo = 'Seleccionar Material',
    bool soloConStock = false,
    int? areaId,
    VoidCallback? onCrearNuevo,
  }) {
    return showModalBottomSheet<MaterialModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SelectorMaterialModal(
        materiales: materiales,
        titulo: titulo,
        soloConStock: soloConStock,
        areaId: areaId,
        onCrearNuevo: onCrearNuevo,
      ),
    );
  }

  @override
  State<SelectorMaterialModal> createState() => _SelectorMaterialModalState();
}

class _SelectorMaterialModalState extends State<SelectorMaterialModal> {
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
    var listaBase = widget.materiales;
    if (widget.areaId != null) {
      listaBase = listaBase.where((m) => m.areaId == widget.areaId).toList();
    }
    if (widget.soloConStock) {
      listaBase = listaBase.where((m) => m.stockTotal > 0).toList();
    }

    final filtrados = _filtro.isEmpty
        ? listaBase
        : listaBase.where((m) {
            return m.nombre.toLowerCase().contains(_filtro) ||
                m.areaNombre.toLowerCase().contains(_filtro) ||
                m.categoriaNombre.toLowerCase().contains(_filtro);
          }).toList();

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.viewInsets.bottom - mediaQuery.padding.top - 24;
    final modalHeight = (mediaQuery.size.height * 0.75).clamp(240.0, availableHeight > 240 ? availableHeight : 240.0);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Container(
        height: modalHeight,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.titulo,
                  style: CeosTheme.heading(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (widget.onCrearNuevo != null)
                  TextButton.icon(
                    onPressed: widget.onCrearNuevo,
                    icon: const Icon(PhosphorIconsRegular.plusCircle, size: 16),
                    label: const Text('Nuevo'),
                    style: TextButton.styleFrom(
                      foregroundColor: CeosColors.areaOdontologia,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar material por nombre, área o categoría...',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                suffixIcon: _filtro.isNotEmpty
                    ? IconButton(
                        icon: const Icon(PhosphorIconsRegular.x, size: 16),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.package, size: 40, color: CeosColors.lightTextMuted),
                          const SizedBox(height: 8),
                          Text(
                            widget.soloConStock
                                ? 'No hay materiales con stock disponible'
                                : 'No se encontraron materiales',
                            style: CeosTheme.body(color: CeosColors.lightTextSecondary),
                          ),
                          if (widget.onCrearNuevo != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: widget.onCrearNuevo,
                              icon: const Icon(PhosphorIconsRegular.plusCircle),
                              label: const Text('Crear nuevo material'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CeosColors.areaOdontologia,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final mat = filtrados[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CeosColors.areaOdontologia.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.cube,
                              color: CeosColors.areaOdontologia,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            mat.nombre,
                            style: CeosTheme.heading(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${mat.areaNombre} • ${mat.categoriaNombre}',
                            style: CeosTheme.body(fontSize: 12, color: CeosColors.lightTextSecondary),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${mat.stockTotal}',
                                style: CeosTheme.dataMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: mat.stockTotal <= 0
                                      ? CeosColors.statusDanger
                                      : CeosColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                mat.unidadMedida,
                                style: CeosTheme.body(fontSize: 10, color: CeosColors.lightTextMuted),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.pop(context, mat),
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
