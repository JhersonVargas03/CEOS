import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';
import '../providers/notificaciones_provider.dart';

class IconoNotificaciones extends ConsumerWidget {
  final VoidCallback onTap;

  const IconoNotificaciones({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noLeidas = ref.watch(contadorNoLeidasProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(PhosphorIconsRegular.bell, size: 24),
          onPressed: onTap,
        ),
        if (noLeidas > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: CeosColors.statusDanger,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                noLeidas > 9 ? '9+' : noLeidas.toString(),
                style: CeosTheme.dataMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
