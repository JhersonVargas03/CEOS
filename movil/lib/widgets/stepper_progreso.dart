import 'package:flutter/material.dart';
import '../core/theme/ceos_colors.dart';
import '../core/theme/ceos_theme.dart';

class StepperProgreso extends StatelessWidget {
  final int pasoActual; // 1-indexed (1, 2, 3)
  final int totalPasos;
  final List<String> titulosPasos;

  const StepperProgreso({
    super.key,
    required this.pasoActual,
    required this.totalPasos,
    this.titulosPasos = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paso $pasoActual de $totalPasos',
              style: CeosTheme.dataMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CeosColors.areaOdontologia,
              ),
            ),
            if (titulosPasos.length >= pasoActual)
              Text(
                titulosPasos[pasoActual - 1],
                style: CeosTheme.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(totalPasos, (index) {
            final isCompleted = index + 1 < pasoActual;
            final isCurrent = index + 1 == pasoActual;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  right: index < totalPasos - 1 ? 6.0 : 0.0,
                ),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isCompleted
                      ? CeosColors.statusSuccess
                      : isCurrent
                          ? CeosColors.areaOdontologia
                          : Colors.grey.withValues(alpha: 0.25),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
