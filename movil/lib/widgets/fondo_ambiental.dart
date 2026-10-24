import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/ceos_colors.dart';

/// Widget decorativo de alto rendimiento que reemplaza fondos planos
/// con un resplandor ambiental orgánico vivo (Ambient Mesh / Aurora Glow)
/// y burbujas de vidrio translúcidas flotantes (Glassmorphic Floating Bubbles).
///
/// Diseñado para correr a 60–120 FPS mediante aceleración por GPU
/// sin interceptar gestos táctiles y aislando el repintado en un RepaintBoundary.
class FondoAmbiental extends StatefulWidget {
  final Widget child;
  final bool conResplandorSuperior;
  final bool conResplandorInferior;
  final bool conBurbujas;
  final bool conAnimacion;

  const FondoAmbiental({
    super.key,
    required this.child,
    this.conResplandorSuperior = true,
    this.conResplandorInferior = true,
    this.conBurbujas = true,
    this.conAnimacion = true,
  });

  @override
  State<FondoAmbiental> createState() => _FondoAmbientalState();
}

class _FondoAmbientalState extends State<FondoAmbiental>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    if (widget.conAnimacion) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FondoAmbiental oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conAnimacion != oldWidget.conAnimacion) {
      if (widget.conAnimacion) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? CeosColors.darkBackground : CeosColors.lightBackground;

    return ColoredBox(
      color: baseBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Capa de animación ambiental continua GPU aislada
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AmbientGlowPainter(
                  animation: _controller,
                  isDark: isDark,
                  conSuperior: widget.conResplandorSuperior,
                  conInferior: widget.conResplandorInferior,
                  conBurbujas: widget.conBurbujas,
                ),
              ),
            ),
          ),
          // Contenido Principal
          widget.child,
        ],
      ),
    );
  }
}

/// Especificación precalculada de burbujas flotantes para evitar instanciaciones en paint()
class _BurbujaSpec {
  final double x; // Posición base horizontal normalizada [0.0, 1.0]
  final double startY; // Posición vertical inicial [0.0, 1.30]
  final double radius; // Radio en píxeles lógicos
  final int cycles; // Múltiplo entero de ciclos verticales por período completo (garantiza loop continuo)
  final int driftHarmonic; // Armónico entero de oscilación horizontal (1 o 2)
  final double phase; // Desfase angular para movimiento oscilatorio horizontal
  final int colorType; // 0: Cian, 1: Púrpura/Índigo, 2: Teal/Esmeralda, 3: Azul

  const _BurbujaSpec({
    required this.x,
    required this.startY,
    required this.radius,
    required this.cycles,
    required this.driftHarmonic,
    required this.phase,
    required this.colorType,
  });
}

// 7 burbujas con ciclos enteros y desfases armónicos exactos para loop perfecto
const List<_BurbujaSpec> _burbujasSpecs = [
  _BurbujaSpec(x: 0.12, startY: 0.95, radius: 26, cycles: 1, driftHarmonic: 1, phase: 0.0, colorType: 0),
  _BurbujaSpec(x: 0.88, startY: 0.70, radius: 34, cycles: 1, driftHarmonic: 1, phase: 1.5, colorType: 1),
  _BurbujaSpec(x: 0.28, startY: 0.40, radius: 18, cycles: 2, driftHarmonic: 2, phase: 2.8, colorType: 2),
  _BurbujaSpec(x: 0.76, startY: 0.25, radius: 22, cycles: 1, driftHarmonic: 1, phase: 0.8, colorType: 0),
  _BurbujaSpec(x: 0.45, startY: 1.10, radius: 36, cycles: 1, driftHarmonic: 1, phase: 3.6, colorType: 3),
  _BurbujaSpec(x: 0.62, startY: 0.55, radius: 16, cycles: 2, driftHarmonic: 2, phase: 2.1, colorType: 1),
  _BurbujaSpec(x: 0.92, startY: 1.20, radius: 28, cycles: 1, driftHarmonic: 1, phase: 4.2, colorType: 2),
];

class _AmbientGlowPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDark;
  final bool conSuperior;
  final bool conInferior;
  final bool conBurbujas;

  _AmbientGlowPainter({
    required this.animation,
    required this.isDark,
    required this.conSuperior,
    required this.conInferior,
    required this.conBurbujas,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final t = animation.value;
    final angle = t * 2 * math.pi;
    final rect = Offset.zero & size;

    // --- 1. ORBES AMBIENTALES DINÁMICOS (Resplandor Aurora en movimiento continuo) ---
    if (conSuperior) {
      // Orbe 1: Cian / Teal respirante en la cabecera derecha
      final cyanColor = isDark
          ? CeosColors.ambientCyan.withValues(alpha: 0.13 + 0.03 * math.sin(angle))
          : CeosColors.ambientCyan.withValues(alpha: 0.06 + 0.02 * math.sin(angle));

      final cyanOffsetX = 0.80 + 0.12 * math.cos(angle);
      final cyanOffsetY = -0.85 + 0.08 * math.sin(angle);

      final paintTopRight = Paint()
        ..shader = RadialGradient(
          center: Alignment(cyanOffsetX, cyanOffsetY),
          radius: 0.85 + 0.08 * math.cos(angle),
          colors: [
            cyanColor,
            cyanColor.withValues(alpha: 0.0),
          ],
        ).createShader(rect);

      canvas.drawRect(rect, paintTopRight);

      // Orbe 2: Púrpura / Índigo respirante en la cabecera izquierda
      final purpleColor = isDark
          ? CeosColors.ambientPurple.withValues(alpha: 0.10 + 0.02 * math.cos(angle))
          : CeosColors.ambientPurple.withValues(alpha: 0.04 + 0.01 * math.cos(angle));

      final purpleOffsetX = -0.85 + 0.10 * math.sin(angle);
      final purpleOffsetY = -0.55 + 0.12 * math.cos(angle);

      final paintTopLeft = Paint()
        ..shader = RadialGradient(
          center: Alignment(purpleOffsetX, purpleOffsetY),
          radius: 0.78 + 0.06 * math.sin(angle),
          colors: [
            purpleColor,
            purpleColor.withValues(alpha: 0.0),
          ],
        ).createShader(rect);

      canvas.drawRect(rect, paintTopLeft);
    }

    if (conInferior) {
      // Orbe 3: Azul Zafiro en la parte inferior media-derecha
      final blueColor = isDark
          ? CeosColors.ambientBlue.withValues(alpha: 0.08 + 0.02 * math.sin(angle))
          : const Color(0xFFBAE6FD).withValues(alpha: 0.07 + 0.02 * math.sin(angle));

      final blueOffsetX = 0.25 + 0.15 * math.sin(angle * 0.8);
      final blueOffsetY = 0.90 + 0.06 * math.cos(angle * 0.8);

      final paintBottom = Paint()
        ..shader = RadialGradient(
          center: Alignment(blueOffsetX, blueOffsetY),
          radius: 0.88 + 0.06 * math.cos(angle),
          colors: [
            blueColor,
            blueColor.withValues(alpha: 0.0),
          ],
        ).createShader(rect);

      canvas.drawRect(rect, paintBottom);

      // Orbe 4: Teal / Aguamarina en el lateral inferior izquierdo
      final tealColor = isDark
          ? CeosColors.ambientTeal.withValues(alpha: 0.07 + 0.02 * math.cos(angle))
          : CeosColors.ambientTeal.withValues(alpha: 0.04 + 0.01 * math.cos(angle));

      final tealOffsetX = -0.75 + 0.10 * math.cos(angle * 0.9);
      final tealOffsetY = 0.65 + 0.10 * math.sin(angle * 0.9);

      final paintTeal = Paint()
        ..shader = RadialGradient(
          center: Alignment(tealOffsetX, tealOffsetY),
          radius: 0.70 + 0.05 * math.sin(angle),
          colors: [
            tealColor,
            tealColor.withValues(alpha: 0.0),
          ],
        ).createShader(rect);

      canvas.drawRect(rect, paintTeal);
    }

    // --- 2. BURBUJAS DE VIDRIO TRANSLÚCIDAS FLOTANTES (Loop Continuo Fluido) ---
    if (conBurbujas) {
      const double cycleRange = 1.30; // Rango vertical extendido [-0.15, 1.15]

      for (final spec in _burbujasSpecs) {
        // Al usar múltiplos enteros de cycleRange, el módulo en t=0 y t=1 es idéntico: CERO saltos
        final double progress = (spec.startY - (t * spec.cycles * cycleRange)) % cycleRange;
        final double normalizedY = progress - 0.15;
        final double cy = normalizedY * size.height;

        // Deriva sinusoidal armónica exacta (período entero respecto a angle)
        final double drift = math.sin(angle * spec.driftHarmonic + spec.phase) * 16.0;
        final double cx = (spec.x * size.width) + drift;

        // Desvanecimiento suave en bordes superior/inferior para una entrada y salida imperceptibles
        double edgeFade = 1.0;
        if (normalizedY < 0.05) {
          edgeFade = ((normalizedY - (-0.15)) / 0.20).clamp(0.0, 1.0);
        } else if (normalizedY > 0.95) {
          edgeFade = ((1.15 - normalizedY) / 0.20).clamp(0.0, 1.0);
        }

        // Si la burbuja está fuera de los límites de visión, saltamos el dibujado
        if (edgeFade <= 0.01) continue;

        final center = Offset(cx, cy);
        final r = spec.radius * (1.0 + 0.06 * math.sin(angle + spec.phase));

        // Determinar paleta según el tipo de burbuja y modo
        Color mainColor;
        switch (spec.colorType) {
          case 0:
            mainColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
            break;
          case 1:
            mainColor = isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED);
            break;
          case 2:
            mainColor = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
            break;
          default:
            mainColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        }

        // Relleno translúcido esférico con gradiente radial atenuado por edgeFade
        final fillAlpha = (isDark ? 0.09 : 0.07) * edgeFade;
        final fillPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: [
              mainColor.withValues(alpha: fillAlpha * 1.6),
              mainColor.withValues(alpha: fillAlpha * 0.4),
              mainColor.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.65, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r));

        canvas.drawCircle(center, r, fillPaint);

        // Anillo de contorno de vidrio fino (Luminous Rim) atenuado por edgeFade
        final borderAlpha = (isDark ? 0.22 : 0.16) * edgeFade;
        final strokePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..shader = SweepGradient(
            startAngle: 0.0,
            endAngle: math.pi * 2,
            colors: [
              mainColor.withValues(alpha: borderAlpha),
              Colors.white.withValues(alpha: (isDark ? 0.35 : 0.25) * edgeFade),
              mainColor.withValues(alpha: borderAlpha * 0.3),
              mainColor.withValues(alpha: borderAlpha),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
            transform: GradientRotation(angle + spec.phase),
          ).createShader(Rect.fromCircle(center: center, radius: r));

        canvas.drawCircle(center, r, strokePaint);

        // Destello especular de luz 3D (Gloss highlight)
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: (isDark ? 0.30 : 0.38) * edgeFade)
          ..style = PaintingStyle.fill;

        final highlightCenter = Offset(
          center.dx - r * 0.32,
          center.dy - r * 0.32,
        );
        canvas.drawCircle(highlightCenter, r * 0.16, highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.conSuperior != conSuperior ||
        oldDelegate.conInferior != conInferior ||
        oldDelegate.conBurbujas != conBurbujas;
  }
}
