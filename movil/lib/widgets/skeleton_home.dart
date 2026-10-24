import 'package:flutter/material.dart';
import 'ceos_shimmer.dart';

class SkeletonHome extends StatelessWidget {
  const SkeletonHome({super.key});

  Widget _buildBox({required double height, double? width, double borderRadius = 8}) {
    return ShimmerBox(
      height: height,
      width: width,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CeosShimmer(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBox(height: 14, width: 100),
                  const SizedBox(height: 8),
                  _buildBox(height: 22, width: 160),
                ],
              ),
              _buildBox(height: 32, width: 32, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 24),

          // Area Selection Skeleton
          Row(
            children: [
              Expanded(child: _buildBox(height: 90, borderRadius: 12)),
              const SizedBox(width: 12),
              Expanded(child: _buildBox(height: 90, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Access Grid Skeleton
          _buildBox(height: 16, width: 130),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: List.generate(4, (_) => _buildBox(height: 60, borderRadius: 10)),
          ),
          const SizedBox(height: 24),

          // Alerts Skeleton
          _buildBox(height: 16, width: 150),
          const SizedBox(height: 12),
          _buildBox(height: 70, borderRadius: 10),
          const SizedBox(height: 8),
          _buildBox(height: 70, borderRadius: 10),
        ],
      ),
    ),
  );
}
}
