import 'package:flutter/material.dart';
import 'package:stttest/apps/consts/theme.dart';

/// Sleek background component with gradient
class SleekBackground extends StatelessWidget {
  const SleekBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // White background as fallback
      color: AppColors.white,
      // Fill the parent
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Base white background
          Container(
            color: AppColors.white,
          ),
          // Soft gradient overlay using primary pink and minimal blue
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white,
                  AppColors.primary.withValues(alpha: 0.10),
                  AppColors.primary.withValues(alpha: 0.06),
                  AppColors.secondary.withValues(alpha: 0.03),
                  AppColors.white,
                ],
                stops: const [0.0, 0.25, 0.6, 0.85, 1.0],
              ),
            ),
          ),
          // Sphere effects - primary color spheres (pink)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: 80,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: 50,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Minimal blue sphere - only one small accent
          Positioned(
            bottom: 250,
            right: 60,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

