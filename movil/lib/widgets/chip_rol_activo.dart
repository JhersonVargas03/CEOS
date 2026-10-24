import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class ChipRolActivo extends StatelessWidget {
  final String rol;
  final bool esSuperadmin;

  const ChipRolActivo({
    super.key,
    required this.rol,
    this.esSuperadmin = false,
  });

  Color _getColor() {
    if (esSuperadmin || rol.toLowerCase() == 'superadmin') {
      return CeosColors.roleSuperadmin;
    }
    final r = rol.toLowerCase();
    if (r.contains('admin')) return CeosColors.roleAdmin;
    if (r.contains('doc') || r.contains('odonto')) return CeosColors.roleDoctor;
    if (r.contains('gestor') || r.contains('inven')) return CeosColors.roleGestor;
    return CeosColors.roleDefault;
  }

  IconData _getIcon() {
    if (esSuperadmin || rol.toLowerCase() == 'superadmin') {
      return PhosphorIconsFill.crown;
    }
    final r = rol.toLowerCase();
    if (r.contains('admin')) return PhosphorIconsRegular.shieldCheck;
    if (r.contains('doc')) return PhosphorIconsRegular.stethoscope;
    if (r.contains('gestor')) return PhosphorIconsRegular.package;
    return PhosphorIconsRegular.user;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            rol.isNotEmpty ? rol : 'Personal',
            style: CeosTheme.dataMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
