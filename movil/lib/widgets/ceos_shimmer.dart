import 'package:flutter/material.dart';
import '../core/theme/ceos_colors.dart';

/// Efecto de brillo animado (Shimmer) de alto rendimiento para pantallas de carga.
///
/// Adapta automáticamente sus colores según el tema activo (Claro u Oscuro).
class CeosShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const CeosShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<CeosShimmer> createState() => _CeosShimmerState();
}

class _CeosShimmerState extends State<CeosShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? CeosColors.darkCard
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark
        ? const Color(0xFF1E2D4A)
        : const Color(0xFFF8FAFC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: const [0.1, 0.5, 0.9],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}

/// Contenedor rectangular con bordes redondeados diseñado para ser envuelto en CeosShimmer.
class ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? CeosColors.darkCard : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Esqueleto Shimmer animado para listas de inventario o auditoría
class SkeletonListaMateriales extends StatelessWidget {
  final int count;

  const SkeletonListaMateriales({
    super.key,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    return CeosShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const ShimmerBox(height: 40, width: 40, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(height: 14, width: 140, borderRadius: 4),
                    SizedBox(height: 8),
                    ShimmerBox(height: 10, width: 90, borderRadius: 4),
                  ],
                ),
              ),
              const ShimmerBox(height: 18, width: 40, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}
